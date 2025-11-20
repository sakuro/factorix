# frozen_string_literal: true

require_relative "lib/factorix/version"

Gem::Specification.new do |spec|
  spec.name = "factorix"
  spec.version = Factorix::VERSION
  spec.authors = ["OZAWA Sakuro"]
  spec.email = ["10973+sakuro@users.noreply.github.com"]

  spec.summary = "factorix"
  spec.description = "factorix"
  spec.homepage = "https://github.com/sakuro/factorix"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "#{spec.homepage}.git"
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) {
    Dir[
      "lib/**/*.rb",
      "exe/*",
      "sig/**/*.rbs",
      "LICENSE*.txt",
      "README.md",
      "CHANGELOG.md"
    ]
  }
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) {|f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "concurrent-ruby", "~> 1.0"
  spec.add_dependency "dry-auto_inject", "~> 1.0"
  spec.add_dependency "dry-cli", "~> 1.0"
  spec.add_dependency "dry-configurable", "~> 1.0"
  spec.add_dependency "dry-container", "~> 0.11"
  spec.add_dependency "dry-events", "~> 1.1"
  spec.add_dependency "dry-logger", "~> 1.2"
  spec.add_dependency "parslet", "~> 2.0"
  spec.add_dependency "retriable", "~> 3.1"
  spec.add_dependency "rubyzip", "~> 2.3"
  spec.add_dependency "tty-progressbar", "~> 0.18"
  spec.add_dependency "zeitwerk", "~> 2.7"
end
