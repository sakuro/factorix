# frozen_string_literal: true

require "dry/events/publisher"
require "net/http"
require "openssl"

module Factorix
  module Transfer
    # HTTP client for file transfer with event-driven progress notification
    #
    # Publishes events during download/upload operations:
    # - download.started, download.progress, download.completed
    # - upload.started, upload.progress, upload.completed
    class HTTP
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
      private_constant :CHUNK_SIZE

      # Download a file from the given URL with automatic retry and resume support
      #
      # @param url [URI::HTTPS] URL to download from (HTTPS only)
      # @param output [Pathname, String] path to save the downloaded file
      # @return [void]
      # @raise [HTTPError] if the download fails after all retries
      # @raise [ArgumentError] if the URL is not HTTPS
      def download(url, output)
        raise ArgumentError, "URL must be HTTPS" unless url.is_a?(URI::HTTPS)

        output = Pathname(output)

        retry_strategy.with_retry do
          if output.exist?
            download_with_resume(url, output)
          else
            download_full(url, output)
          end
        end
      end

      private def download_full(uri, output)
        request = Net::HTTP::Get.new(uri)
        perform_download(uri, request, output, mode: "wb")
      end

      # Resume a partially downloaded file
      #
      # @param uri [URI::HTTP] URL to download from
      # @param output [Pathname] path to save the downloaded file
      # @return [void]
      private def download_with_resume(uri, output)
        request = Net::HTTP::Get.new(uri)
        request["Range"] = "bytes=#{output.size}-"

        begin
          perform_download(uri, request, output, mode: "ab")
        rescue HTTPClientError => e
          # 416 Range Not Satisfiable - File might have changed, retry full download
          raise unless e.message.include?("416")

          output.delete if output.exist?
          download_full(uri, output)
        end
      end

      # Perform the actual HTTP download
      #
      # @param uri [URI::HTTP] URL to download from
      # @param request [Net::HTTPRequest] HTTP request object
      # @param output [Pathname] path to save the downloaded file
      # @param mode [String] file open mode ("wb" or "ab")
      # @return [void]
      private def perform_download(uri, request, output, mode:)
        http = create_http(uri)

        http.request(request) do |response|
          handle_http_errors(response)

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
        end
      end

      # Create and configure Net::HTTP instance
      #
      # @param uri [URI::HTTP] URI to connect to
      # @return [Net::HTTP] configured HTTP client
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

      # Handle HTTP error responses
      #
      # @param response [Net::HTTPResponse] HTTP response
      # @return [void]
      # @raise [HTTPClientError] for 4xx errors
      # @raise [HTTPServerError] for 5xx errors
      private def handle_http_errors(response)
        case response
        when Net::HTTPSuccess, Net::HTTPPartialContent
          # OK
        when Net::HTTPClientError
          raise HTTPClientError, "#{response.code} #{response.message}"
        when Net::HTTPServerError
          raise HTTPServerError, "#{response.code} #{response.message}"
        else
          raise HTTPError, "#{response.code} #{response.message}"
        end
      end
    end
  end
end
