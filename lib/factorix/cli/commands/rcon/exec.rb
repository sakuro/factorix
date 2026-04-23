# frozen_string_literal: true

require "rcon/client"

module Factorix
  class CLI
    module Commands
      module RCon
        # Execute a Factorio console command via RCon
        class Exec < Base
          desc "Execute a Factorio console command via RCon"

          argument :command, required: true, desc: "Console command to execute (e.g. /server-save)"

          option :host, default: nil, desc: "RCon host"
          option :port, default: nil, desc: "RCon port"
          option :password, default: nil, desc: "RCon password"

          # @param command [String] console command to execute
          # @param host [String, nil] RCon host override
          # @param port [String, nil] RCon port override
          # @param password [String, nil] RCon password override
          # @return [void]
          def call(command:, host: nil, port: nil, password: nil, **)
            rcon_host = host || Factorix.config.rcon.host
            rcon_port = port ? Integer(port) : Factorix.config.rcon.port
            rcon_password = password || Factorix.config.rcon.password

            ::RCon::Client.open(rcon_host, rcon_port, password: rcon_password, sentinel_command: "/c") do |client|
              result = client.execute(command)
              say result unless result.empty?
            end
          rescue ::RCon::Client::ConnectionError => e
            raise RConConnectionError, e.message
          rescue ::RCon::Client::AuthenticationError => e
            raise RConAuthenticationError, e.message
          end
        end
      end
    end
  end
end
