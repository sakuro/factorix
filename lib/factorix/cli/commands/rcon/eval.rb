# frozen_string_literal: true

require "rcon/client"

module Factorix
  class CLI
    module Commands
      module RCon
        # Evaluate a Lua script in Factorio via RCon
        class Eval < Base
          desc "Evaluate a Lua script in Factorio via RCon"

          argument :script, required: false, desc: "Lua script to evaluate; reads from stdin if omitted"

          option :host, default: nil, desc: "RCon host"
          option :port, default: nil, desc: "RCon port"
          option :password, default: nil, desc: "RCon password"

          # @param script [String, nil] Lua script to evaluate; reads from stdin if nil
          # @param host [String, nil] RCon host override
          # @param port [String, nil] RCon port override
          # @param password [String, nil] RCon password override
          # @return [void]
          def call(script: nil, host: nil, port: nil, password: nil, **)
            lua = script || $stdin.read
            rcon_host = host || Factorix.config.rcon.host
            rcon_port = port ? Integer(port) : Factorix.config.rcon.port
            rcon_password = password || Factorix.config.rcon.password

            ::RCon::Client.open(rcon_host, rcon_port, password: rcon_password, sentinel_command: "/c") do |client|
              result = client.execute("/c #{lua}")
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
