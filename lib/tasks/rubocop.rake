# frozen_string_literal: true

require "rubocop/rake_task"

RuboCop::RakeTask.prepend(Module.new do
  # Additionally define rubocop:regenerate_todo task.
  def setup_subtasks(name, *, &task_block)
    super
    namespace name do
      desc "Regenerate RuboCop TODO file"
      task(:regenerate_todo, *) do |_, task_args|
        RakeFileUtils.verbose(verbose) do
          yield(*[self, task_args].slice(0, task_block.arity)) if task_block
          perform("--regenerate-todo")
        end
      end
    end
  end
end)

RuboCop::RakeTask.new
