# frozen_string_literal: true

source "https://rubygems.org"

gemspec

group :development, :test do
  gem "irb"
  gem "repl_type_completor"
end

group :develop do
  gem "rake"

  gem "rubocop"
  gem "rubocop-performance"
  gem "rubocop-rake"
  gem "rubocop-rspec"
  gem "rubocop-thread_safety"

  # Using main until Data support is released
  gem "yard", github: "lsegal/yard", ref: "5b93b3a"
end

group :test do
  gem "rspec"
  gem "simplecov", require: false

  gem "vcr"
  gem "webmock"
end
