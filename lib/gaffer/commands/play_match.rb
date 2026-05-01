# frozen_string_literal: true

require "pastel"

module Gaffer
  module Commands
    # Friendly at your stadium: managed club hosts a classic foil opponent (CRW ⇄ MBW).
    module PlayMatch
      SquadPair = Struct.new(:home_players, :away_players, keyword_init: true)

      class << self
        def foil_short(manager_short_name)
          manager_short_name.to_s.casecmp?("MBW") ? "CRW" : "MBW"
        end

        # @param pastel [Pastel]
        # @param out [IO]
        def run(pastel: Pastel.new, out: $stdout)
          ensure_db_connected

          unless (manager = resolve_manager)
            abort_with(out, pastel.red("No manager profile loaded — restart and complete onboarding."))
            return
          end

          unless (home = resolve_managed_club(manager))
            abort_with(out, pastel.red("Your managed club vanished from the database."))
            return
          end

          unless (away = resolve_away_foil_club(home))
            sn = foil_short(home.short_name)
            abort_with(out, pastel.red("Could not find foil club #{sn.inspect} — run rake db:seed."))
            return
          end

          unless (squads = resolve_both_squads(home, away))
            abort_with(out, pastel.red("One club has no squad in the database."))
            return
          end

          result = simulate_balanced(
            home:, away:,
            home_players: squads.home_players,
            away_players: squads.away_players
          )

          render_match_result(out:, pastel:, home:, away:, result:)
        end

        private

        def ensure_db_connected
          Gaffer::Database.prepare
        end

        def resolve_manager
          mgr = Repositories::ManagerRepository.current
          return nil unless mgr&.managed_club_id

          mgr
        end

        # @return [Gaffer::Domain::Club, nil]
        def resolve_managed_club(manager)
          Repositories::ClubRepository.find(manager.managed_club_id)
        end

        # @return [Gaffer::Domain::Club, nil]
        def resolve_away_foil_club(home)
          sn = foil_short(home.short_name)
          row = Gaffer::Database.db[:clubs].where(short_name: sn.upcase).first
          return nil unless row

          Repositories::ClubRepository.find(row[:id])
        end

        # @return [SquadPair, nil] nil if either side has no players
        def resolve_both_squads(home, away)
          home_players = Repositories::PlayerRepository.for_club(home.id)
          away_players = Repositories::PlayerRepository.for_club(away.id)
          return nil if home_players.empty? || away_players.empty?

          SquadPair.new(home_players:, away_players:)
        end

        def simulate_balanced(home:, away:, home_players:, away_players:)
          Domain::MatchEngine.new.simulate(
            home_club: home,
            home_players: home_players,
            away_club: away,
            away_players: away_players,
            home_tactic: :balanced,
            away_tactic: :balanced
          )
        end

        def render_match_result(out:, pastel:, home:, away:, result:)
          line_w = [52, "#{home.name} #{away.name}".length + 28].max

          out.puts pastel.dim("─" * line_w)
          out.puts pastel.bold.white("MATCH RESULT")
          out.puts pastel.dim("friendly · #{away.name} rolling into town · full time")
          out.puts

          hg = pastel.bold.green(result.home_score.to_s.rjust(2))
          ag = pastel.bold.green(result.away_score.to_s.rjust(2))

          out.puts "  #{pastel.bold(home.name)}  #{hg}#{pastel.dim(" - ")}#{ag}  #{pastel.bold(away.name)}"
          hs = result.home_scorers.map(&:name).join(", ")
          aws = result.away_scorers.map(&:name).join(", ")
          sc_line =
            if hs.empty? && aws.empty?
              pastel.dim("  —  vs  —")
            else
              "  #{pastel.dim(hs.empty? ? "—" : hs)}#{pastel.dim("  vs  ")}#{pastel.dim(aws.empty? ? "—" : aws)}"
            end
          out.puts sc_line
          out.puts pastel.dim("  λ (expected goals-ish) #{result.home_xg_lambda.round(2)} : #{result.away_xg_lambda.round(2)}")
          out.puts pastel.dim("─" * line_w)
        end

        def abort_with(out, message)
          out.puts message
        end
      end
    end
  end
end
