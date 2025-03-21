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

  # This branch supports Data subclasses being correctly documented as classes, rather than constants.
  # https://github.com/lsegal/yard/pull/1600
  gem "yard", github: "marshall-lee/yard", branch: "data-define"
end

group :test do
  gem "rspec"
  gem "simplecov", require: false
end
