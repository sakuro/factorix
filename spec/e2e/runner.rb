# frozen_string_literal: true

require "fileutils"
require "open3"
require "pathname"
require "perfect_toml"
require "rbconfig"
require "tmpdir"
require "yaml"

module E2E
  # Executes a language-neutral CLI test case (format: e2e/README.md)
  #
  # The runner is intentionally thin: everything that defines a case lives in
  # its case.yaml so that the same data can drive other implementations of the
  # CLI (see doc/go-migration-roadmap.md).
  class Runner
    ROOT = Pathname(__dir__).parent.parent
    private_constant :ROOT

    EXECUTABLE = ROOT / "exe" / "factorix"
    private_constant :EXECUTABLE

    SANDBOX_PLACEHOLDER = "{{SANDBOX}}"
    private_constant :SANDBOX_PLACEHOLDER

    Result = Data.define(:stdout, :status, :expected_status, :expected_stdout, :expected_stdout_pattern)

    # @param case_dir [Pathname] directory containing case.yaml
    def initialize(case_dir)
      @case_dir = case_dir
      @definition = YAML.safe_load_file(case_dir / "case.yaml")
    end

    # Run the case in a fresh sandbox
    #
    # @return [Result] actual output and resolved expectations
    def call
      Dir.mktmpdir("factorix-e2e-") do |dir|
        sandbox = Pathname(dir)
        prepare_sandbox(sandbox)
        stdout, _stderr, process_status = execute(sandbox)
        build_result(stdout, process_status, sandbox)
      end
    end

    private def prepare_sandbox(sandbox)
      %w[cwd xdg-cache xdg-config xdg-data xdg-state].each {|name| (sandbox / name).mkpath }
      @definition.fetch("dirs", []).each {|dir| (sandbox / dir).mkpath }
      place_files(sandbox)
      render_config(sandbox)
    end

    private def place_files(sandbox)
      @definition.fetch("files", []).each do |entry|
        from = entry.fetch("from")
        source = from.start_with?("//") ? ROOT / from.delete_prefix("//") : @case_dir / from
        destination = sandbox / substitute(entry.fetch("to"), sandbox)
        destination.dirname.mkpath
        FileUtils.cp_r(source, destination)
      end
    end

    # Renders the abstract config mapping into the configuration format of the
    # implementation under test — TOML, shared with the future Go driver.
    private def render_config(sandbox)
      config = @definition["config"]
      return unless config

      (sandbox / "config.toml").write(PerfectTOML.generate(substitute_values(config, sandbox)))
    end

    private def substitute_values(value, sandbox)
      case value
      when Hash
        value.transform_values {|val| substitute_values(val, sandbox) }
      when String
        substitute(value, sandbox)
      else
        value
      end
    end

    private def execute(sandbox)
      config_path = sandbox / "config.toml"
      env = {
        "NO_COLOR" => "1",
        "XDG_CACHE_HOME" => (sandbox / "xdg-cache").to_s,
        "XDG_CONFIG_HOME" => (sandbox / "xdg-config").to_s,
        "XDG_DATA_HOME" => (sandbox / "xdg-data").to_s,
        "XDG_STATE_HOME" => (sandbox / "xdg-state").to_s,
        "FACTORIX_CONFIG" => config_path.exist? ? config_path.to_s : nil
      }
      command = [RbConfig.ruby, EXECUTABLE.to_s, *@definition.fetch("command")]

      Open3.capture3(env, *command, stdin_data: @definition.fetch("stdin", ""), chdir: (sandbox / "cwd").to_s)
    end

    private def build_result(stdout, process_status, sandbox)
      expectation = @definition.fetch("expect")
      stdout_expectation = expectation.fetch("stdout", {})

      expected_stdout =
        if stdout_expectation.key?("file")
          substitute((@case_dir / stdout_expectation.fetch("file")).read, sandbox)
        end

      Result[
        stdout:,
        status: process_status.exitstatus,
        expected_status: expectation.fetch("status"),
        expected_stdout:,
        expected_stdout_pattern: stdout_expectation["match"]
      ]
    end

    private def substitute(text, sandbox) = text.gsub(SANDBOX_PLACEHOLDER, sandbox.to_s)
  end
end
