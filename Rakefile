# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

Dir["lib/tasks/*.rake"].each { load it }

task default: %i[spec rubocop]
