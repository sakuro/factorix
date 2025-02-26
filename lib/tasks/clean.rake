# frozen_string_literal: true

require "rake/clean"

CLEAN.include("coverage/*")
CLEAN.include("doc/*")
CLOBBER.include("coverage")
CLOBBER.include("doc")
