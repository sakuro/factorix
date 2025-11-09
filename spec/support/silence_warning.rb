# frozen_string_literal: true

# Shared context to suppress Kernel#warn output during tests
RSpec.shared_context "with Kernel#warn silenced" do
  around do |example|
    original_stderr = $stderr.dup
    $stderr.reopen(IO::NULL)
    example.run
  ensure
    $stderr.reopen(original_stderr)
    original_stderr.close
  end
end

# Automatically include the shared context for tests tagged with warn: :silence
RSpec.configure do |config|
  config.include_context "with Kernel#warn silenced", warn: :silence
end
