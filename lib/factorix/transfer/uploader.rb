# frozen_string_literal: true

require "dry/events"
require "securerandom"
require "uri"

module Factorix
  module Transfer
    # File uploader with automatic retry
    #
    # Uploads files to given URLs using HTTP multipart/form-data.
    # Uses Transfer::HTTP for the actual upload with event-driven progress notification.
    class Uploader
      include Factorix::Import[
        :logger,
        client: :upload_http_client
      ]
      include Dry::Events::Publisher[:uploader]

      register_event("upload.started")
      register_event("upload.progress")
      register_event("upload.completed")

      # Upload a file to the given URL with optional form fields
      #
      # @param url [URI::HTTPS, String] URL to upload to (HTTPS only)
      # @param file_path [Pathname, String] path to the file to upload
      # @param field_name [String] form field name for the file (default: "file")
      # @param fields [Hash<String, String>] additional form fields (e.g., metadata)
      # @return [void]
      # @raise [ArgumentError] if the URL is not HTTPS or file doesn't exist
      # @raise [HTTPClientError] for 4xx errors
      # @raise [HTTPServerError] for 5xx errors
      # @raise [HTTPError] for other HTTP errors
      def upload(url, file_path, field_name: "file", fields: {})
        url = URI(url) if url.is_a?(String)
        unless url.is_a?(URI::HTTPS)
          logger.error("Invalid URL: must be HTTPS", url: url.to_s)
          raise ArgumentError, "URL must be HTTPS"
        end

        file_path = Pathname(file_path)
        unless file_path.exist?
          logger.error("File does not exist", path: file_path.to_s)
          raise ArgumentError, "File does not exist: #{file_path}"
        end

        upload_file_with_progress(url, file_path, field_name, fields)
      end

      private def upload_file_with_progress(url, file_path, field_name, fields)
        boundary = generate_boundary
        file_size = file_path.size

        publish("upload.started", total_size: file_size)

        # Build multipart body parts
        body_parts = []

        # Add additional form fields first
        fields.each do |name, value|
          body_parts << "--#{boundary}\r\n"
          body_parts << "Content-Disposition: form-data; name=\"#{name}\"\r\n"
          body_parts << "\r\n"
          body_parts << "#{value}\r\n"
        end

        # Add file field
        body_parts << "--#{boundary}\r\n"
        body_parts << "Content-Disposition: form-data; name=\"#{field_name}\"; filename=\"#{file_path.basename}\"\r\n"
        body_parts << "Content-Type: application/zip\r\n"
        body_parts << "\r\n"

        # Calculate total size
        header_size = body_parts.join.bytesize
        footer_size = "\r\n--#{boundary}--\r\n".bytesize
        total_size = header_size + file_size + footer_size

        # Build the multipart stream
        body_stream = build_multipart_stream(body_parts, file_path, boundary)

        # Wrap in progress tracking IO
        progress_stream = ProgressIO.new(body_stream, total_size) do |uploaded|
          publish("upload.progress", current_size: uploaded, total_size:)
        end

        # POST with the multipart stream
        client.post(
          url,
          body: progress_stream,
          headers: {"Content-Length" => total_size.to_s},
          content_type: "multipart/form-data; boundary=#{boundary}"
        )

        publish("upload.completed", total_size:)
      end

      # Generate a random boundary for multipart/form-data
      #
      # @return [String] boundary string
      private def generate_boundary
        "----RubyFormBoundary#{SecureRandom.hex(16)}"
      end

      # Build a multipart stream from body parts, file, and boundary
      #
      # @param body_parts [Array<String>] header parts
      # @param file_path [Pathname] file to upload
      # @param boundary [String] multipart boundary
      # @return [IO] combined IO stream
      private def build_multipart_stream(body_parts, file_path, boundary)
        header = StringIO.new(body_parts.join)
        file = file_path.open("rb")
        footer = StringIO.new("\r\n--#{boundary}--\r\n")

        CombinedIO.new(header, file, footer)
      end

      # Wrapper IO that tracks read progress
      class ProgressIO
        # @param io [IO] underlying IO stream
        # @param total_size [Integer] total size in bytes
        # @yield [Integer] current number of bytes read
        def initialize(io, total_size, &block)
          @io = io
          @total_size = total_size
          @current = 0
          @callback = block
        end

        # Read data from underlying IO and track progress
        #
        # @param length [Integer, nil] number of bytes to read
        # @param outbuf [String, nil] output buffer
        # @return [String, nil] read data or nil at EOF
        def read(length=nil, outbuf=nil)
          data = @io.read(length, outbuf)
          if data
            @current += data.bytesize
            @callback&.call(@current)
          end
          data
        end

        # Check if at end of stream
        #
        # @return [Boolean] true if at EOF
        def eof?
          @io.eof?
        end

        # Close underlying IO
        #
        # @return [void]
        def close
          @io.close
        end

        # Rewind underlying IO
        #
        # @return [void]
        def rewind
          @io.rewind
          @current = 0
        end

        # Get current size
        #
        # @return [Integer] total size
        def size
          @total_size
        end
      end

      # Combined IO that concatenates multiple IO streams
      class CombinedIO
        # @param ios [Array<IO>] IO streams to concatenate
        def initialize(*ios)
          @ios = ios
          @index = 0
        end

        # Read from current IO, advancing to next when exhausted
        #
        # @param length [Integer, nil] number of bytes to read
        # @param outbuf [String, nil] output buffer
        # @return [String, nil] read data or nil at EOF
        def read(length=nil, outbuf=nil)
          return nil if @index >= @ios.size

          data = @ios[@index].read(length, outbuf)
          if data.nil? || data.empty?
            @index += 1
            return read(length, outbuf)
          end
          data
        end

        # Check if all streams are exhausted
        #
        # @return [Boolean] true if at EOF
        def eof?
          @index >= @ios.size
        end

        # Close all IO streams
        #
        # @return [void]
        def close
          @ios.each(&:close)
        end

        # Rewind all streams
        #
        # @return [void]
        def rewind
          @ios.each(&:rewind)
          @index = 0
        end

        # Get total size of all streams
        #
        # @return [Integer] total size
        def size
          @ios.sum(&:size)
        end
      end
    end
  end
end
