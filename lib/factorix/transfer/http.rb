# frozen_string_literal: true

require "dry/events/publisher"
require "net/http"
require "openssl"
require "securerandom"
require "stringio"

module Factorix
  module Transfer
    # HTTP client for file transfer with event-driven progress notification
    #
    # Publishes events during download/upload operations:
    # - download.started, download.progress, download.completed
    # - upload.started, upload.progress, upload.completed
    class HTTP
      # @!parse
      #   # @return [RetryStrategy]
      #   attr_reader :retry_strategy
      include Factorix::Import["retry_strategy"]
      include Dry::Events::Publisher[:transfer]

      register_event("download.started")
      register_event("download.progress")
      register_event("download.completed")
      register_event("upload.started")
      register_event("upload.progress")
      register_event("upload.completed")

      # Chunk size for reading/writing (16KB)
      CHUNK_SIZE = 16 * 1024

      # Maximum number of redirects to follow
      MAX_REDIRECTS = 10
      private_constant :MAX_REDIRECTS
      private_constant :CHUNK_SIZE

      # Download a file from the given URL with automatic retry and resume support
      #
      # @param url [URI::HTTPS] URL to download from (HTTPS only)
      # @param output [Pathname, String] path to save the downloaded file
      # @return [void]
      # @raise [ArgumentError] if the URL is not HTTPS
      # @raise [HTTPClientError] for 4xx HTTP errors
      # @raise [HTTPServerError] for 5xx HTTP errors
      def download(url, output, redirect_count: 0)
        raise ArgumentError, "URL must be HTTPS" unless url.is_a?(URI::HTTPS)
        raise ArgumentError, "Too many redirects (#{redirect_count})" if redirect_count > MAX_REDIRECTS

        output = Pathname(output)

        retry_strategy.with_retry do
          if output.exist?
            download_with_resume(url, output, redirect_count:)
          else
            download_full(url, output, redirect_count:)
          end
        end
      end

      # Upload a file to the given URL using multipart/form-data
      #
      # @param url [URI::HTTPS] URL to upload to (HTTPS only)
      # @param file_path [Pathname, String] path to the file to upload
      # @param field_name [String] form field name for the file (default: "file")
      # @return [void]
      # @raise [ArgumentError] if the URL is not HTTPS or file does not exist
      # @raise [HTTPClientError] for 4xx HTTP errors
      # @raise [HTTPServerError] for 5xx HTTP errors
      def upload(url, file_path, field_name: "file")
        raise ArgumentError, "URL must be HTTPS" unless url.is_a?(URI::HTTPS)

        file_path = Pathname(file_path)
        raise ArgumentError, "File does not exist: #{file_path}" unless file_path.exist?

        retry_strategy.with_retry do
          perform_upload(url, file_path, field_name)
        end
      end

      private private def download_full(uri, output, redirect_count:)
        request = Net::HTTP::Get.new(uri)
        perform_download(uri, request, output, mode: "wb", redirect_count:)
      end

      # Resume a partially downloaded file
      #
      # @param uri [URI::HTTP] URL to download from
      # @param output [Pathname] path to save the downloaded file
      # @return [void]
      private private def download_with_resume(uri, output, redirect_count:)
        request = Net::HTTP::Get.new(uri)
        request["Range"] = "bytes=#{output.size}-"

        begin
          perform_download(uri, request, output, mode: "ab", redirect_count:)
        rescue HTTPClientError => e
          raise unless e.message.include?("416")

          # 416 Range Not Satisfiable - File might have changed, retry full download
          output.delete if output.exist?
          download_full(uri, output, redirect_count:)
        end
      end

      # Perform the actual HTTP download
      #
      # @param uri [URI::HTTP] URL to download from
      # @param request [Net::HTTPRequest] HTTP request object
      # @param output [Pathname] path to save the downloaded file
      # @param mode [String] file open mode ("wb" or "ab")
      # @return [void]
      private private def perform_download(uri, request, output, mode:, redirect_count:)
        http = create_http(uri)

        http.request(request) do |response|
          handle_download_response(response, output, mode, redirect_count)
        end
      end

      # Handle the HTTP response for download
      #
      # @param response [Net::HTTPResponse] HTTP response object
      # @param output [Pathname] path to save the downloaded file
      # @param mode [String] file open mode ("wb" or "ab")
      # @param redirect_count [Integer] current redirect count
      # @return [void]
      private def handle_download_response(response, output, mode, redirect_count)
        case response
        when Net::HTTPSuccess, Net::HTTPPartialContent
          total_size = extract_content_length(response)
          current_size = mode == "ab" ? output.size : 0

          publish("download.started", total_size:)

          output.open(mode) do |file|
            response.read_body do |chunk|
              file.write(chunk)
              current_size += chunk.bytesize
              publish("download.progress", current_size:, total_size:)
            end
          end

          publish("download.completed", total_size:)

        when Net::HTTPRedirection
          location = response["Location"]
          redirect_url = URI(location)
          # Follow redirect recursively
          download(redirect_url, output, redirect_count: redirect_count + 1)

        when Net::HTTPClientError
          raise HTTPClientError, "#{response.code} #{response.message}"

        when Net::HTTPServerError
          raise HTTPServerError, "#{response.code} #{response.message}"

        else
          raise HTTPError, "#{response.code} #{response.message}"
        end
      end

      # Create and configure Net::HTTP instance
      #
      # @param uri [URI::HTTP] URI to connect to
      # @return [Net::HTTP] configured HTTP client
      # Perform the actual HTTP upload
      #
      # @param uri [URI::HTTPS] URL to upload to
      # @param file_path [Pathname] path to the file to upload
      # @param field_name [String] form field name
      # @return [void]
      private private def perform_upload(uri, file_path, field_name)
        http = create_http(uri)
        boundary = generate_boundary
        file_size = file_path.size

        publish("upload.started", total_size: file_size)

        request = Net::HTTP::Post.new(uri)
        request["Content-Type"] = "multipart/form-data; boundary=#{boundary}"

        # Build multipart body
        body_parts = []

        # File part header
        body_parts << "--#{boundary}\r\n"
        body_parts << "Content-Disposition: form-data; name=\"#{field_name}\"; filename=\"#{file_path.basename}\"\r\n"
        body_parts << "Content-Type: application/zip\r\n"
        body_parts << "\r\n"

        # Calculate total size
        header_size = body_parts.join.bytesize
        footer_size = "\r\n--#{boundary}--\r\n".bytesize
        total_size = header_size + file_size + footer_size

        request["Content-Length"] = total_size.to_s

        # Set request body using IO streaming
        request.body_stream = build_multipart_stream(body_parts, file_path, boundary)

        # Custom body stream that tracks progress
        original_stream = request.body_stream
        request.body_stream = ProgressIO.new(original_stream, total_size) do |uploaded|
          publish("upload.progress", current_size: uploaded, total_size:)
        end

        response = http.request(request)

        case response
        when Net::HTTPSuccess
          publish("upload.completed", total_size:)
          nil

        when Net::HTTPClientError
          raise HTTPClientError, "#{response.code} #{response.message}"

        when Net::HTTPServerError
          raise HTTPServerError, "#{response.code} #{response.message}"

        else
          raise HTTPError, "#{response.code} #{response.message}"
        end
      end

      # Generate a unique boundary string for multipart/form-data
      #
      # @return [String] boundary string
      private def generate_boundary
        "----RubyFormBoundary#{SecureRandom.hex(16)}"
      end

      # Build multipart stream from parts
      #
      # @param header_parts [Array<String>] header parts
      # @param file_path [Pathname] file to upload
      # @param boundary [String] boundary string
      # @return [IO] multipart stream
      private def build_multipart_stream(header_parts, file_path, boundary)
        header = header_parts.join
        footer = "\r\n--#{boundary}--\r\n"

        # Concatenate header, file, and footer as a single stream
        parts = [
          StringIO.new(header),
          file_path.open("rb"),
          StringIO.new(footer)
        ]

        MultipartStream.new(parts)
      end

      private def create_http(uri)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        http.open_timeout = Application.config.http.connect_timeout
        http.read_timeout = Application.config.http.read_timeout
        http.write_timeout = Application.config.http.write_timeout if http.respond_to?(:write_timeout=)
        http
      end

      # Extract content length from HTTP response
      #
      # @param response [Net::HTTPResponse] HTTP response
      # @return [Integer, nil] content length in bytes, or nil if not available
      private def extract_content_length(response)
        content_length = response["Content-Length"]
        content_length ? Integer(content_length, 10) : nil
      end
    end

    # IO wrapper that tracks read progress
    class ProgressIO
      def initialize(io, total_size, &block)
        @io = io
        @total_size = total_size
        @progress_callback = block
        @uploaded = 0
      end

      # Read data from underlying IO and track progress
      #
      # @param length [Integer, nil] number of bytes to read
      # @param outbuf [String, nil] output buffer
      # @return [String, nil] data read
      def read(length=nil, outbuf=nil)
        data = @io.read(length, outbuf)
        if data
          @uploaded += data.bytesize
          @progress_callback&.call(@uploaded)
        end
        data
      end

      # Get total size
      #
      # @return [Integer] total size
      def size
        @total_size
      end

      # Rewind IO and reset progress
      #
      # @return [void]
      def rewind
        @io.rewind
        @uploaded = 0
      end
    end

    # Stream that concatenates multiple IO objects
    class MultipartStream
      def initialize(parts)
        @parts = parts
        @current_part_index = 0
      end

      # Read data from multiple IO parts
      #
      # @param length [Integer, nil] number of bytes to read
      # @param outbuf [String, nil] output buffer
      # @return [String, nil] data read
      def read(length=nil, outbuf=nil)
        return nil if finished?

        data = prepare_buffer(outbuf)
        remaining = length

        read_from_parts(data, remaining)

        data.empty? ? nil : data
      end

      # Rewind all parts
      #
      # @return [void]
      def rewind
        @parts.each(&:rewind)
        @current_part_index = 0
      end

      private def finished?
        @current_part_index >= @parts.size
      end

      private def prepare_buffer(outbuf)
        outbuf.nil? ? +"" : outbuf.clear
      end

      private def read_from_parts(data, remaining)
        read_chunk_from_current_part(data, remaining) while @current_part_index < @parts.size && more_to_read?(remaining)
      end

      private def more_to_read?(remaining)
        remaining.nil? || remaining > 0
      end

      private def read_chunk_from_current_part(data, remaining)
        current_part = @parts[@current_part_index]
        chunk = current_part.read(remaining)

        if chunk.nil? || chunk.empty?
          @current_part_index += 1
        else
          data << chunk
          remaining - chunk.bytesize if remaining
        end
      end
    end
  end
end
