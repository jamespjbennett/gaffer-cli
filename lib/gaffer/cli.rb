# frozen_string_literal: true

require "thor"

module Gaffer
  class CLI < Thor
    map c: :console

    desc "console", "Start IRB with Gaffer and database loaded"
    long_desc <<~HELP
      Connects using GAFFER_DB_PATH or ./db/gaffer.sqlite then opens IRB.

      In IRB use `db` for Sequel datasets, e.g. db[:clubs].first, or Gaffer::Repositories::*.
    HELP
    def console(*)
      require_relative "console"
      Gaffer::Console.start
    end

    desc "version", "Print version"
    def version
      puts Gaffer::VERSION
    end

    default_task :version
  end
end
