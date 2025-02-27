# frozen_string_literal: true

# Mock of Sys::Proctable
#
# Loading "darwin/sys/proctable" on non-MacOS platform (in CI) will raise LoadError
# when it loads "ffi" and tries linking "libproc".
# We must mock the entire Sys::ProcTable.ps method to avoid this.

module Sys
  # mock ProcTable class
  class ProcTable
    def self.ps
      []
    end
  end
end

# Struct for mocking Sys::ProcTable.ps
#
# This is a mock of the Struct returned by Sys::ProcTable.ps
Struct::ProcTableStruct = Struct.new(:pid, :cmdline)
