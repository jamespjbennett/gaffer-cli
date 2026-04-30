# frozen_string_literal: true

require "thor"

module Gaffer
  class CLI < Thor
    map c: :console

    desc "next", "Play the upcoming league gameweek (simulate every fixture in this round)"
    def next(*)
      require_relative "../gaffer"
      require "pastel"
      require_relative "commands/next_fixture"
      require "tty-prompt"
      Gaffer::Commands::NextFixture.run(pastel: Pastel.new, out: $stdout, prompt: TTY::Prompt.new)
    end

    desc "start", "Open the main menu (interactive)"
    def start(*)
      require_relative "ui/menu"
      Ui::Menu.run
    end

    desc "console", "Start IRB with Gaffer and database loaded"
    long_desc <<~HELP
      Connects using GAFFER_DB_PATH or ./db/gaffer.sqlite then opens IRB.

      In IRB use `db` for Sequel datasets, e.g. db[:clubs].first, or Gaffer::Repositories::*.
    HELP
    def console(*)
      require_relative "console"
      Console.start
    end

    desc "version", "Print version"
    def version
      puts Gaffer::VERSION
    end

    default_task :start
  end
end
