# frozen_string_literal: true

RSpec.describe Factorix::CLI::Commands::MOD::Check do
  let(:runtime) do
    instance_double(
      Factorix::Runtime::Base,
      factorix_config_path: Pathname("/tmp/factorix/config.rb"),
      mod_list_path:,
      mod_dir: Pathname("/fake/path/mods"),
      data_dir: Pathname("/fake/path/data"),
      running?: false
    )
  end
  let(:logger) { instance_double(Dry::Logger::Dispatcher, debug: nil) }
  let(:command) { Factorix::CLI::Commands::MOD::Check.new(runtime:, logger:) }
  let(:mod_list_path) { Pathname("/fake/path/mod-list.json") }
  let(:mod_list) { instance_spy(Factorix::MODList) }
  let(:graph) { instance_spy(Factorix::Dependency::Graph) }
  let(:validator) { instance_double(Factorix::Dependency::Validator) }
  let(:validation_result) { instance_double(Factorix::Dependency::ValidationResult) }

  before do
    allow(Factorix::Container).to receive(:load_config)
    allow(Factorix::MODList).to receive(:load).and_return(mod_list)
    allow(Factorix::InstalledMOD).to receive(:all).and_return([])
    allow(Factorix::Dependency::Graph::Builder).to receive(:build).and_return(graph)
    allow(graph).to receive(:nodes).and_return([])
    allow(Factorix::Dependency::Validator).to receive(:new).and_return(validator)
    allow(validator).to receive(:validate).and_return(validation_result)
  end

  describe "#call" do
    context "when validation succeeds without warnings" do
      let(:node1) { instance_double(Factorix::Dependency::Node, enabled?: true) }
      let(:node2) { instance_double(Factorix::Dependency::Node, enabled?: true) }

      before do
        allow(graph).to receive(:nodes).and_return([node1, node2])
        allow(validation_result).to receive_messages(
          valid?: true,
          warnings?: false,
          errors?: false,
          suggestions?: false
        )
      end

      it "displays success messages" do
        result = run_command(command)
        expect(result.stdout).to include("All enabled MOD(s) have their required dependencies satisfied")
        expect(result.stdout).to include("No circular dependencies detected")
        expect(result.stdout).to include("No conflicting MOD(s) are enabled simultaneously")
      end

      it "displays summary with enabled count" do
        result = run_command(command)
        expect(result.stdout).to include("Summary: 2 enabled MODs")
      end

      it "does not exit with error code" do
        result = run_command(command)
        expect(result.success?).to be true
      end
    end

    context "when validation succeeds with warnings" do
      let(:node1) { instance_double(Factorix::Dependency::Node, enabled?: true) }
      let(:warning) do
        Factorix::Dependency::ValidationResult::Warning[
          type: :mod_installed_not_in_list,
          message: "MOD X may have compatibility issues",
          mod: nil
        ]
      end

      before do
        allow(graph).to receive(:nodes).and_return([node1])
        allow(validation_result).to receive_messages(
          valid?: true,
          warnings?: true,
          errors?: false,
          suggestions?: false,
          warnings: [warning]
        )
      end

      it "does not display success messages" do
        result = run_command(command)
        expect(result.stdout).not_to include("All enabled MOD(s)")
      end

      it "displays warnings" do
        result = run_command(command)
        expect(result.stdout).to include("Warnings:")
        expect(result.stdout).to include("MOD X may have compatibility issues")
      end

      it "displays summary with warning count" do
        result = run_command(command)
        expect(result.stdout).to include("Summary: 1 enabled MOD, 1 warning")
      end

      it "does not exit with error code" do
        result = run_command(command)
        expect(result.success?).to be true
      end
    end

    context "when validation fails with errors" do
      let(:node1) { instance_double(Factorix::Dependency::Node, enabled?: true) }
      let(:node2) { instance_double(Factorix::Dependency::Node, enabled?: true) }
      let(:error1) do
        Factorix::Dependency::ValidationResult::Error[
          type: :missing_dependency,
          message: "Missing dependency: mod-a",
          mod: nil,
          dependency: nil
        ]
      end
      let(:error2) do
        Factorix::Dependency::ValidationResult::Error[
          type: :circular_dependency,
          message: "Circular dependency detected",
          mod: nil,
          dependency: nil
        ]
      end

      before do
        allow(graph).to receive(:nodes).and_return([node1, node2])
        allow(validation_result).to receive_messages(
          valid?: false,
          warnings?: false,
          errors?: true,
          suggestions?: false,
          errors: [error1, error2]
        )
      end

      it "displays errors" do
        result = run_command(command, rescue_exception: true)
        expect(result.stdout).to include("Errors:")
        expect(result.stdout).to include("Missing dependency: mod-a")
        expect(result.stdout).to include("Circular dependency detected")
      end

      it "displays summary with error count" do
        result = run_command(command, rescue_exception: true)
        expect(result.stdout).to include("Summary: 2 enabled MODs, 2 errors")
      end

      it "raises ValidationError" do
        expect {
          run_command(command)
        }.to raise_error(Factorix::ValidationError, /MOD dependency validation failed/)
      end
    end

    context "when validation fails with both errors and warnings" do
      let(:node1) { instance_double(Factorix::Dependency::Node, enabled?: true) }
      let(:error) do
        Factorix::Dependency::ValidationResult::Error[
          type: :missing_dependency,
          message: "Missing dependency",
          mod: nil,
          dependency: nil
        ]
      end
      let(:warning) do
        Factorix::Dependency::ValidationResult::Warning[
          type: :mod_in_list_not_installed,
          message: "Version mismatch",
          mod: nil
        ]
      end

      before do
        allow(graph).to receive(:nodes).and_return([node1])
        allow(validation_result).to receive_messages(
          valid?: false,
          warnings?: true,
          errors?: true,
          suggestions?: false,
          errors: [error],
          warnings: [warning]
        )
      end

      it "displays both errors and warnings" do
        result = run_command(command, rescue_exception: true)
        expect(result.stdout).to include("Errors:")
        expect(result.stdout).to include("Missing dependency")
        expect(result.stdout).to include("Warnings:")
        expect(result.stdout).to include("Version mismatch")
      end

      it "displays summary with both counts" do
        result = run_command(command, rescue_exception: true)
        expect(result.stdout).to include("Summary: 1 enabled MOD, 1 error, 1 warning")
      end
    end

    context "when there are suggestions" do
      let(:node1) { instance_double(Factorix::Dependency::Node, enabled?: true) }
      let(:suggestion1) do
        Factorix::Dependency::ValidationResult::Suggestion[
          message: "Consider enabling mod-x",
          mod: Factorix::MOD[name: "mod-x"],
          version: "1.0.0"
        ]
      end
      let(:suggestion2) do
        Factorix::Dependency::ValidationResult::Suggestion[
          message: "Update mod-y to latest version",
          mod: Factorix::MOD[name: "mod-y"],
          version: "2.0.0"
        ]
      end

      before do
        allow(graph).to receive(:nodes).and_return([node1])
        allow(validation_result).to receive_messages(
          valid?: true,
          warnings?: false,
          errors?: false,
          suggestions?: true,
          suggestions: [suggestion1, suggestion2]
        )
      end

      it "displays suggestions" do
        result = run_command(command)
        expect(result.stdout).to include("Suggestions:")
        expect(result.stdout).to include("Consider enabling mod-x")
        expect(result.stdout).to include("Update mod-y to latest version")
      end
    end

    context "with singular counts in summary" do
      let(:node1) { instance_double(Factorix::Dependency::Node, enabled?: true) }
      let(:error) do
        Factorix::Dependency::ValidationResult::Error[
          type: :missing_dependency,
          message: "Error",
          mod: nil,
          dependency: nil
        ]
      end
      let(:warning) do
        Factorix::Dependency::ValidationResult::Warning[
          type: :mod_in_list_not_installed,
          message: "Warning",
          mod: nil
        ]
      end

      before do
        allow(graph).to receive(:nodes).and_return([node1])
        allow(validation_result).to receive_messages(
          valid?: false,
          warnings?: true,
          errors?: true,
          suggestions?: false,
          errors: [error],
          warnings: [warning]
        )
      end

      it "uses singular forms correctly" do
        result = run_command(command, rescue_exception: true)
        expect(result.stdout).to include("Summary: 1 enabled MOD, 1 error, 1 warning")
      end
    end

    context "with zero enabled MODs" do
      before do
        allow(graph).to receive(:nodes).and_return([])
        allow(validation_result).to receive_messages(
          valid?: true,
          warnings?: false,
          errors?: false,
          suggestions?: false
        )
      end

      it "displays zero in summary" do
        result = run_command(command)
        expect(result.stdout).to include("Summary: 0 enabled MODs")
      end
    end
  end
end
