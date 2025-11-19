# frozen_string_literal: true

RSpec.describe Factorix::CLI::Commands::MOD::Check do
  let(:command) { Factorix::CLI::Commands::MOD::Check.new }
  let(:mod_list_path) { Pathname("/fake/path/mod-list.json") }
  let(:mod_list) { instance_spy(Factorix::MODList) }
  let(:graph) { instance_spy(Factorix::Dependency::Graph) }
  let(:validator) { instance_double(Factorix::Dependency::Validator) }
  let(:validation_result) { instance_double(Factorix::Dependency::ValidationResult) }

  before do
    # Runtime is already mocked by "with mock runtime" shared context
    allow(Factorix::Runtime).to receive(:detect).and_return(runtime)
    allow(runtime).to receive(:mod_list_path).and_return(mod_list_path)

    # Mock Application.load_config
    allow(Factorix::Application).to receive(:load_config)

    # Mock MODList
    allow(Factorix::MODList).to receive(:load).and_return(mod_list)

    # Mock InstalledMOD.all
    allow(Factorix::InstalledMOD).to receive(:all).and_return([])

    # Mock Graph::Builder
    allow(Factorix::Dependency::Graph::Builder).to receive(:build).and_return(graph)
    allow(graph).to receive(:nodes).and_return([])

    # Mock Validator
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
        output = capture_stdout { command.call }
        expect(output).to include("✅ All enabled MODs have their required dependencies satisfied")
        expect(output).to include("✅ No circular dependencies detected")
        expect(output).to include("✅ No conflicting MODs are enabled simultaneously")
      end

      it "displays summary with enabled count" do
        output = capture_stdout { command.call }
        expect(output).to include("Summary: 2 enabled MODs")
      end

      it "does not exit with error code" do
        expect { capture_stdout { command.call } }.not_to raise_error
      end
    end

    context "when validation succeeds with warnings" do
      let(:node1) { instance_double(Factorix::Dependency::Node, enabled?: true) }
      let(:warning) do
        Factorix::Dependency::ValidationResult::Warning.new(
          type: :mod_installed_not_in_list,
          message: "MOD X may have compatibility issues",
          mod: nil
        )
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
        output = capture_stdout { command.call }
        expect(output).not_to include("✅ All enabled MODs")
      end

      it "displays warnings" do
        output = capture_stdout { command.call }
        expect(output).to include("Warnings:")
        expect(output).to include("MOD X may have compatibility issues")
      end

      it "displays summary with warning count" do
        output = capture_stdout { command.call }
        expect(output).to include("Summary: 1 enabled MOD, 1 warning")
      end

      it "does not exit with error code" do
        expect { capture_stdout { command.call } }.not_to raise_error
      end
    end

    context "when validation fails with errors" do
      let(:node1) { instance_double(Factorix::Dependency::Node, enabled?: true) }
      let(:node2) { instance_double(Factorix::Dependency::Node, enabled?: true) }
      let(:error1) do
        Factorix::Dependency::ValidationResult::Error.new(
          type: :missing_dependency,
          message: "Missing dependency: mod-a",
          mod: nil,
          dependency: nil
        )
      end
      let(:error2) do
        Factorix::Dependency::ValidationResult::Error.new(
          type: :circular_dependency,
          message: "Circular dependency detected",
          mod: nil,
          dependency: nil
        )
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
        output = capture_stdout {
          begin
            command.call
          rescue SystemExit
            # Expected exit
          end
        }
        expect(output).to include("Errors:")
        expect(output).to include("Missing dependency: mod-a")
        expect(output).to include("Circular dependency detected")
      end

      it "displays summary with error count" do
        output = capture_stdout {
          begin
            command.call
          rescue SystemExit
            # Expected exit
          end
        }
        expect(output).to include("Summary: 2 enabled MODs, 2 errors")
      end

      it "exits with error code 1" do
        expect {
          capture_stdout { command.call }
        }.to raise_error(SystemExit) do |error|
          expect(error.status).to eq(1)
        end
      end
    end

    context "when validation fails with both errors and warnings" do
      let(:node1) { instance_double(Factorix::Dependency::Node, enabled?: true) }
      let(:error) do
        Factorix::Dependency::ValidationResult::Error.new(
          type: :missing_dependency,
          message: "Missing dependency",
          mod: nil,
          dependency: nil
        )
      end
      let(:warning) do
        Factorix::Dependency::ValidationResult::Warning.new(
          type: :mod_in_list_not_installed,
          message: "Version mismatch",
          mod: nil
        )
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
        output = capture_stdout {
          begin
            command.call
          rescue SystemExit
            # Expected exit
          end
        }
        expect(output).to include("Errors:")
        expect(output).to include("Missing dependency")
        expect(output).to include("Warnings:")
        expect(output).to include("Version mismatch")
      end

      it "displays summary with both counts" do
        output = capture_stdout {
          begin
            command.call
          rescue SystemExit
            # Expected exit
          end
        }
        expect(output).to include("Summary: 1 enabled MOD, 1 error, 1 warning")
      end
    end

    context "when there are suggestions" do
      let(:node1) { instance_double(Factorix::Dependency::Node, enabled?: true) }
      let(:suggestion1) do
        Factorix::Dependency::ValidationResult::Suggestion.new(
          message: "Consider enabling mod-x",
          mod: Factorix::MOD[name: "mod-x"],
          version: "1.0.0"
        )
      end
      let(:suggestion2) do
        Factorix::Dependency::ValidationResult::Suggestion.new(
          message: "Update mod-y to latest version",
          mod: Factorix::MOD[name: "mod-y"],
          version: "2.0.0"
        )
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
        output = capture_stdout { command.call }
        expect(output).to include("💡 Suggestions:")
        expect(output).to include("Consider enabling mod-x")
        expect(output).to include("Update mod-y to latest version")
      end
    end

    context "with singular counts in summary" do
      let(:node1) { instance_double(Factorix::Dependency::Node, enabled?: true) }
      let(:error) do
        Factorix::Dependency::ValidationResult::Error.new(
          type: :missing_dependency,
          message: "Error",
          mod: nil,
          dependency: nil
        )
      end
      let(:warning) do
        Factorix::Dependency::ValidationResult::Warning.new(
          type: :mod_in_list_not_installed,
          message: "Warning",
          mod: nil
        )
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
        output = capture_stdout {
          begin
            command.call
          rescue SystemExit
            # Expected exit
          end
        }
        expect(output).to include("Summary: 1 enabled MOD, 1 error, 1 warning")
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
        output = capture_stdout { command.call }
        expect(output).to include("Summary: 0 enabled MODs")
      end
    end
  end
end
