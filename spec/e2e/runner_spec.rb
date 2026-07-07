# frozen_string_literal: true

require_relative "runner"

RSpec.describe E2E::Runner do
  cases_root = Pathname(__dir__).parent.parent / "e2e" / "cases"

  Pathname.glob(cases_root / "**" / "case.yaml").sort.each do |case_yaml|
    name = case_yaml.dirname.relative_path_from(cases_root).to_s

    it "passes case #{name}", case_dir: case_yaml.dirname do |example|
      result = E2E::Runner.new(example.metadata[:case_dir]).call

      aggregate_failures do
        expect(result.status).to eq(result.expected_status)
        expect(result.stdout).to eq(result.expected_stdout) if result.expected_stdout
        expect(result.stdout).to match(Regexp.new(result.expected_stdout_pattern)) if result.expected_stdout_pattern
      end
    end
  end
end
