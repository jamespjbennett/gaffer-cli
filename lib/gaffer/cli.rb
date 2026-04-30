# frozen_string_literal: true

require "thor"

module Gaffer
  class CLI < Thor
    map c: :console

    desc "table", "Standings — active league default; use --previous or --year for archives"
    method_option :previous, type: :boolean, default: false, aliases: "-p",
                  desc: "Show the newest completed league"
    method_option :year, type: :numeric,
                  banner: "YEAR",
                  desc: "Show standings for the most recent league with this calendar year"
    def table(*)
      require_relative "../gaffer"
      require "pastel"
      require_relative "commands/league_standings"

      yr = options[:year]
      yr = Integer(yr) unless yr.nil?

      Gaffer::Commands::LeagueStandings.run(
        pastel: Pastel.new,
        out: $stdout,
        previous: options[:previous],
        year: yr
      )
    end

    desc "fixtures", "Fixtures & results — active league; use --previous or --year for archives"
    method_option :previous, type: :boolean, default: false, aliases: "-p",
                  desc: "Show the newest completed league"
    method_option :year, type: :numeric,
                  banner: "YEAR",
                  desc: "Show fixtures for the most recent league with this calendar year"
    def fixtures(*)
      require_relative "../gaffer"
      require "pastel"
      require_relative "commands/season_fixtures"

      yr = options[:year]
      yr = Integer(yr) unless yr.nil?

      Gaffer::Commands::SeasonFixtures.run(
        pastel: Pastel.new,
        out: $stdout,
        previous: options[:previous],
        year: yr
      )
    end

    desc "scorers", "Top scorers — active league by default; use --previous or --year for archives"
    method_option :previous, type: :boolean, default: false, aliases: "-p",
                  desc: "Show the newest completed league"
    method_option :year, type: :numeric,
                  banner: "YEAR",
                  desc: "Show scorers for the most recent league with this calendar year"
    def scorers(*)
      require_relative "../gaffer"
      require "pastel"
      require_relative "commands/top_scorers"

      yr = options[:year]
      yr = Integer(yr) unless yr.nil?

      Gaffer::Commands::TopScorers.run(
        pastel: Pastel.new,
        out: $stdout,
        previous: options[:previous],
        year: yr
      )
    end

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
