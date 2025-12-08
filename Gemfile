# frozen_string_literal: true

source "https://rubygems.org"

gemspec

group :development, :test do
  gem "rake", require: false

  gem "irb", require: false
  gem "repl_type_completor", require: false
end

group :development do
  # Ruby Language Server
  gem "debug", require: false
  gem "ruby-lsp", require: false

  # RuboCop
  gem "docquet", require: false # An opionated RuboCop config tool
  gem "rubocop", require: false
  gem "rubocop-performance", require: false
  gem "rubocop-rake", require: false
  gem "rubocop-rspec", require: false
  gem "rubocop-thread_safety", require: false

  # Type checking
  gem "steep", require: false

  # YARD
  gem "redcarpet", require: false
  gem "yard", require: false
end

group :test do
  # RSpec & SimpleCov
  gem "rspec", require: false
  gem "simplecov", require: false
  gem "webmock", require: false
end
