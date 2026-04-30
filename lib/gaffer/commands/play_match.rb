# frozen_string_literal: true

require "pastel"

module Gaffer
  module Commands
    # Friendly at your stadium: managed club hosts a classic foil opponent (CRW ⇄ MBW).
    module PlayMatch
      module_function

      # Fixed pair from the seeded five — keeps matchups plausible while we wait on fixtures.
      def foil_short(manager_short_name)
        manager_short_name.to_s.casecmp?("MBW") ? "CRW" : "MBW"
      end

      def run(pastel: Pastel.new, out: $stdout)
        Gaffer::Database.connect

        mgr = Repositories::ManagerRepository.current
        unless mgr&.managed_club_id
          out.puts pastel.red("No manager profile loaded — restart and complete onboarding.")
          return
        end

        home = Repositories::ClubRepository.find(mgr.managed_club_id)
        unless home
          out.puts pastel.red("Your managed club vanished from the database.")
          return
        end

        away_sn = foil_short(home.short_name)
        away_row = Gaffer::Database.db[:clubs].where(short_name: away_sn.upcase).first
        unless away_row
          out.puts pastel.red("Could not find foil club #{away_sn.inspect} — run rake db:seed.")
          return
        end

        away = Repositories::ClubRepository.find(away_row[:id])

        home_players = Repositories::PlayerRepository.for_club(home.id)
        away_players = Repositories::PlayerRepository.for_club(away.id)

        if home_players.empty? || away_players.empty?
          out.puts pastel.red("One club has no squad in the database.")
          return
        end

        result = Domain::MatchEngine.new.simulate(
          home_club: home,
          home_players: home_players,
          away_club: away,
          away_players: away_players,
          home_tactic: :balanced,
          away_tactic: :balanced
        )

        line_w = [52, "#{home.name} #{away.name}".length + 28].max

        out.puts pastel.dim("─" * line_w)
        ft = pastel.dim("friendly · #{away.name} rolling into town · full time")
        out.puts pastel.bold.white("MATCH RESULT")
        out.puts ft
        out.puts

        hg = pastel.bold.green(result.home_score.to_s.rjust(2))
        ag = pastel.bold.green(result.away_score.to_s.rjust(2))

        out.puts "  #{pastel.bold(home.name)}  #{hg}#{pastel.dim(" - ")}#{ag}  #{pastel.bold(away.name)}"
        out.puts pastel.dim("  λ (expected goals-ish) #{result.home_xg_lambda.round(2)} : #{result.away_xg_lambda.round(2)}")
        out.puts pastel.dim("─" * line_w)
      end
    end
  end
end
