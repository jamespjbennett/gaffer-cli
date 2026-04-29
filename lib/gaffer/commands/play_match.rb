# frozen_string_literal: true

require "pastel"

module Gaffer
  module Commands
    # Friendly: Crowden Rovers (home) vs Millbrook Wanderers (away) — requires `rake db:seed`.
    module PlayMatch
      module_function

      HOME_SHORT = "CRW"
      AWAY_SHORT = "MBW"

      def run(pastel: Pastel.new, out: $stdout)
        Gaffer::Database.connect

        home_row = Gaffer::Database.db[:clubs].where(short_name: HOME_SHORT).first
        away_row = Gaffer::Database.db[:clubs].where(short_name: AWAY_SHORT).first
        unless home_row && away_row
          out.puts pastel.red("Could not find seeded clubs #{HOME_SHORT} (home) and #{AWAY_SHORT} (away).")
          out.puts pastel.dim("Run: bundle exec rake db:seed")
          return
        end

        home = Gaffer::Repositories::ClubRepository.find(home_row[:id])
        away = Gaffer::Repositories::ClubRepository.find(away_row[:id])

        home_players = Gaffer::Repositories::PlayerRepository.for_club(home.id)
        away_players = Gaffer::Repositories::PlayerRepository.for_club(away.id)

        if home_players.empty? || away_players.empty?
          out.puts pastel.red("One club has no squad in the database.")
          return
        end

        result = Gaffer::Domain::MatchEngine.new.simulate(
          home_club: home,
          home_players: home_players,
          away_club: away,
          away_players: away_players,
          home_tactic: :balanced,
          away_tactic: :balanced
        )

        out.puts pastel.dim("─" * 52)
        out.puts pastel.bold.white("MATCH RESULT · friendly · full time")
        out.puts

        hg = pastel.bold.green(result.home_score.to_s.rjust(2))
        ag = pastel.bold.green(result.away_score.to_s.rjust(2))

        out.puts "  #{pastel.bold(home.name)}  #{hg}#{pastel.dim(" - ")}#{ag}  #{pastel.bold(away.name)}"
        out.puts pastel.dim("  λ (expected goals-ish) #{result.home_xg_lambda.round(2)} : #{result.away_xg_lambda.round(2)}")
        out.puts pastel.dim("─" * 52)
      end
    end
  end
end
