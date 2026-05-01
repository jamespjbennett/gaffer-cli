# frozen_string_literal: true

require_relative "../../domain/lineup"
require_relative "../../domain/match"
require_relative "../../domain/fixture"
require_relative "../../domain/goal_event"
require_relative "../../repositories/player_repository"

module Gaffer
  module Commands
    module Support
      # One fixture simulation + domain rows for persistence (single plan argument).
      module GameweekRoundSim
        Plan = Data.define(
          :fixture,
          :clubs_by_id,
          :engine,
          :seed,
          :home_tactic,
          :away_tactic,
          :managed_club_id,
          :managed_xi
        )

        module_function

        def simulate(plan)
          fx = plan.fixture
          hid = fx.home_club_id.to_i
          aid = fx.away_club_id.to_i
          mid = plan.managed_club_id.to_i
          picks = xi_pair(plan:, hid:, aid:, mid:)
          home_club = plan.clubs_by_id.fetch(fx.home_club_id)
          away_club = plan.clubs_by_id.fetch(fx.away_club_id)
          plan.engine.simulate(
            home_club: home_club,
            home_players: picks.first,
            away_club: away_club,
            away_players: picks.last,
            home_tactic: plan.home_tactic,
            away_tactic: plan.away_tactic,
            seed: plan.seed
          )
        end

        def build_match(fixture_id:, result:)
          Domain::Match.new(
            id: nil,
            fixture_id: fixture_id.to_i,
            home_score: result.home_score,
            away_score: result.away_score,
            home_possession: nil,
            home_shots: nil,
            home_shots_ot: nil,
            away_shots: nil,
            away_shots_ot: nil,
            events: [],
            player_ratings: {},
            narrative: nil
          )
        end

        def fixture_played(fx)
          Domain::Fixture.new(
            id: fx.id,
            season_id: fx.season_id,
            gameweek: fx.gameweek,
            home_club_id: fx.home_club_id,
            away_club_id: fx.away_club_id,
            played: true
          )
        end

        def goal_events_for_fixture(fx, result)
          hid = fx.home_club_id.to_i
          aid = fx.away_club_id.to_i
          fid = fx.id.to_i
          home =
            goal_events(side_scorers(result.home_scorers), fixture_id: fid, club_id: hid, side: "home")
          away =
            goal_events(side_scorers(result.away_scorers), fixture_id: fid, club_id: aid, side: "away")
          home + away
        end

        def xi_pair(plan:, hid:, aid:, mid:)
          home_full = Repositories::PlayerRepository.for_club(hid)
          away_full = Repositories::PlayerRepository.for_club(aid)
          raise KeyError, "home XI empty" if home_full.empty?
          raise KeyError, "away XI empty" if away_full.empty?

          home_pick = hid == mid ? plan.managed_xi : Domain::Lineup.pick_best_xi(home_full)
          away_pick = aid == mid ? plan.managed_xi : Domain::Lineup.pick_best_xi(away_full)
          unless home_pick.size == 11 && away_pick.size == 11
            raise KeyError, "XI must be eleven each side"
          end

          [home_pick, away_pick]
        end

        def side_scorers(players)
          Array(players).filter_map do |p|
            pid = p&.id.to_i
            pid if pid.positive?
          end
        end

        def goal_events(player_ids, fixture_id:, club_id:, side:)
          player_ids.map do |pid|
            Domain::GoalEvent.new(id: nil, fixture_id:, player_id: pid, club_id:, side:)
          end
        end
      end
    end
  end
end
