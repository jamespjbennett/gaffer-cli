# frozen_string_literal: true

require_relative "../../domain/lineup"
require_relative "../../repositories/league_repository"
require_relative "../../repositories/manager_repository"
require_relative "../../repositories/club_repository"
require_relative "../../repositories/fixture_repository"
require_relative "../../repositories/player_repository"
require_relative "gameweek_play_state"
require_relative "gameweek_round_tty"

module Gaffer
  module Commands
    module Support
      # Validates league · schedule · XI availability before scout. Returns [`GameweekPlayState`] or a status symbol.
      module GameweekPreflight
        class << self
          # @return [GameweekPlayState, Symbol]
          def call(pastel:, out:, prompt:)
            league = Repositories::LeagueRepository.active
            return absent_league(pastel, out) unless league

            mgr = Repositories::ManagerRepository.current
            cid = mgr&.managed_club_id.to_i
            unless mgr && cid.positive?
              out.puts pastel.red("No manager profile — complete onboarding first.")
              return :no_manager
            end

            clubs = Repositories::ClubRepository.for_league(league.id)
            return empty_league_slots(pastel, out) if clubs.empty?

            clubs_by_id = clubs.each_with_object({}) { |c, h| h[c.id] = c }
            managed_next =
              Repositories::FixtureRepository.next_for_club(season_id: league.id, club_id: cid)

            unless managed_next
              return finalize_if_exhausted(league, cid, pastel, out, prompt) if schedule_exhausted?(league.id)

              nag_corrupt_schedule(pastel, out, league.id)
              return :fixture_data_error
            end

            round_err = validate_round(league:, managed_next:, pastel:, out:)
            return round_err if round_err

            gw = managed_next.gameweek.to_i
            rounds = Repositories::FixtureRepository.for_season_and_gameweek(season_id: league.id, gameweek: gw)
            max_gw = Repositories::FixtureRepository.max_gameweek(league.id)
            return bad_max_gw(pastel, out) if max_gw <= 0

            xi_err = squad_blockers(pastel, out, cid)
            return xi_err if xi_err

            full = Repositories::PlayerRepository.for_club(cid)
            opp_id = opponent_id(managed_next, cid)
            Support::GameweekPlayState.new(
              league: league,
              managed_club_id: cid,
              clubs_by_id: clubs_by_id,
              managed_next: managed_next,
              gameweek: gw,
              round_fixtures: rounds,
              max_gw: max_gw,
              full_squad: full,
              suggested_xi: Domain::Lineup.pick_best_xi(full),
              managed_club: clubs_by_id.fetch(cid),
              opponent_club: clubs_by_id.fetch(opp_id.to_i),
              opponent_name_short: clubs_by_id.fetch(opp_id.to_i).name.to_s.strip,
              hosting_managed: managed_next.home_club_id.to_i == cid.to_i
            )
          end

          private

          def finalize_if_exhausted(league, managed_club_id, pastel, out, prompt)
            GameweekRoundTty.finalize_already_settled(
              league:,
              managed_club_id:,
              pastel:,
              out:,
              prompt:
            )
          end

          def schedule_exhausted?(league_id)
            Repositories::FixtureRepository.unplayed_count(league_id).zero?
          end

          def absent_league(pastel, out)
            out.puts pastel.dim("There is no active league — choose “Start new season” from the menu.")
            :no_active_league
          end

          def empty_league_slots(pastel, out)
            out.puts pastel.red("No clubs linked to this league.")
            :fixture_data_error
          end

          def nag_corrupt_schedule(pastel, out, league_id)
            remaining = Repositories::FixtureRepository.unplayed_count(league_id)
            out.puts pastel.red("#{remaining} unplayed fixtures remain but none involve your squad — corrupt schedule.")
          end

          def validate_round(league:, managed_next:, pastel:, out:)
            gw = managed_next.gameweek.to_i
            rounds =
              Repositories::FixtureRepository.for_season_and_gameweek(season_id: league.id, gameweek: gw)
            return round_empty(pastel, out, gw) unless rounds.any?
            return partially_played(pastel, out, gw) if rounds.any?(&:played?)

            nil
          end

          def round_empty(pastel, out, gw)
            out.puts pastel.red("Gameweek #{gw} scheduled nothing in SQLite.")
            :fixture_data_error
          end

          def partially_played(pastel, out, gw)
            out.puts pastel.red("Gameweek #{gw} partially played — refusing to rewind.")
            :fixture_data_error
          end

          def bad_max_gw(pastel, out)
            out.puts pastel.red("Fixture list empty for this league.")
            :fixture_data_error
          end

          def squad_blockers(pastel, out, cid)
            full = Repositories::PlayerRepository.for_club(cid)
            return roster_empty(pastel, out) if full.empty?

            sug = Domain::Lineup.pick_best_xi(full)
            return xi_shortfall(pastel, out, full.size) unless sug.size == 11

            nil
          end

          def roster_empty(pastel, out)
            out.puts pastel.red("Your club has zero players loaded — rerun db seed.")
            :squads_incomplete
          end

          def xi_shortfall(pastel, out, roster_size)
            out.puts pastel.red("Not enough registered players (#{roster_size}) to stitch an XI.")
            :squads_incomplete
          end

          def opponent_id(managed_next, mid)
            tmp = mid.to_i
            managed_next.home_club_id.to_i == tmp ? managed_next.away_club_id : managed_next.home_club_id
          end
        end
      end
    end
  end
end
