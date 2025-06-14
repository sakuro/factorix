# frozen_string_literal: true

require "rake/clean"

CLEAN.include("coverage/*")
CLEAN.include("docs/api/*")
CLOBBER.include("coverage")
CLOBBER.include("docs/api")
