# frozen_string_literal: true

require_relative "../../domain/scout_report"
require_relative "../../repositories/player_repository"
require_relative "scout_build_input"
require_relative "scout_league_snapshot"
require_relative "scout_xi_ratings"
require_relative "scout_top_scorer_lookup"
require_relative "scout_recent_form"
require_relative "scout_watch_focus"
require_relative "scout_coaching_notables"

module Gaffer
  module Commands
    module Support
      # Assembles a [`Domain::ScoutReport`] from repositories + domain helpers (tables, Lineup, MatchEngine).
      # Companion pieces live in [`ScoutRecentForm`], [`ScoutWatchFocus`], [`ScoutLeagueSnapshot`], etc.
      module ScoutReportBuilder
        class << self
          # @param engine [#attack_defense_rating_for_xi] defaults to Domain::MatchEngine
          # @return [Domain::ScoutReport]
          def build(opponent_club:, league_id:, managed_club:, gameweek:, hosting_managed:, engine: nil)
            input =
              ScoutBuildInput
                .from_build_kwargs(
                  opponent_club:,
                  managed_club:,
                  league_id:,
                  gameweek:,
                  hosting_managed:,
                  engine:
                )
                .validate!

            snap = ScoutLeagueSnapshot.for_season(input.season_id)
            oid = input.opponent_id
            mid = input.managed_id
            eng = input.engine

            opp_row = snap.row_for_club(oid)
            mgr_row = snap.row_for_club(mid)

            table_report(input:, snap:, oid:, mid:, opp_row:, mgr_row:, eng:)
          end

          # @param chronological_results [Array<Hash>] as from FixtureRepository#settled_scores_for_season
          # @return [Array<Symbol>] last five :w, :d, :l from opponent POV (oldest first among those five)
          def recent_form_for(opponent_club_id:, chronological_results:)
            ScoutRecentForm.last_five(opponent_club_id:, chronological_results:)
          end

          # @param managed_xi [Array<Domain::Player>] suggested XI before dugout tweaks
          # @return [Domain::CoachingContext]
          def build_coaching_context(managed_club:, managed_xi:)
            ScoutCoachingNotables.context(managed_club:, managed_xi:)
          end

          private

          def table_report(input:, snap:, oid:, mid:, opp_row:, mgr_row:, eng:)
            league_size = snap.league_size
            atk_def = ScoutXiRatings.pair(engine: eng, club: input.opponent_club, squad_club_id: oid)
            ours = ScoutXiRatings.pair(engine: eng, club: input.managed_club, squad_club_id: mid)
            opp_players = Repositories::PlayerRepository.for_club(oid)
            top = ScoutTopScorerLookup.for_club(league_id: input.season_id, opponent_club_id: oid)

            Domain::ScoutReport.new(
              opponent: input.opponent_club,
              managed_club: input.managed_club,
              gameweek: input.gameweek,
              hosting_managed: input.hosting_managed,
              league_position: snap.slot_for(oid),
              league_size: league_size,
              played: opp_row&.played.to_i,
              manager_league_position: snap.slot_for(mid),
              manager_played: mgr_row&.played.to_i,
              manager_points: mgr_row&.points.to_i,
              opponent_points: opp_row&.points.to_i,
              recent_form:
                ScoutRecentForm.last_five(opponent_club_id: oid, chronological_results: snap.results),
              attack_rating: atk_def[0],
              defence_rating: atk_def[1],
              our_attack_rating: ours[0],
              our_defence_rating: ours[1],
              top_scorer: top,
              watch_focus: ScoutWatchFocus.pick(top_scorer: top, opp_players: opp_players)
            )
          end

        end
      end
    end
  end
end
