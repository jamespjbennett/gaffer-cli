# frozen_string_literal: true

require_relative "../../database"
require_relative "../../domain/league"
require_relative "../../repositories/league_repository"
require_relative "../../repositories/match_repository"
require_relative "../../repositories/goal_event_repository"
require_relative "../../repositories/fixture_repository"
require_relative "gameweek_round_sim"
require_relative "gameweek_tactics"

module Gaffer
  module Commands
    module Support
      # Simulates every fixture in the round and bumps league state inside one DB transaction.
      module GameweekRoundPersist
        class << self
          def run_transaction(state:, manager_shape:, user_xi:, summary_class:, engine:)
            summaries = []
            mid = state.managed_club_id

            Gaffer::Database.db.transaction do
              state.round_fixtures.each do |fx|
                persist_one_fixture(
                  fx:,
                  state:,
                  mid:,
                  manager_shape:,
                  user_xi:,
                  engine:,
                  summaries:,
                  summary_class:
                )
              end
              save_league_progress(state)
            end

            summaries
          end

          private

          def persist_one_fixture(fx:, state:, mid:, manager_shape:, user_xi:, engine:, summaries:, summary_class:)
            home_tac, away_tac = GameweekTactics.tactics_pair_for(fixture: fx, managed_id: mid, shape: manager_shape)
            plan =
              GameweekRoundSim::Plan.new(
                fixture: fx,
                clubs_by_id: state.clubs_by_id,
                engine: engine,
                seed: fx.id.to_i,
                home_tactic: home_tac,
                away_tactic: away_tac,
                managed_club_id: mid,
                managed_xi: user_xi
              )
            result = GameweekRoundSim.simulate(plan)
            Repositories::MatchRepository.save(GameweekRoundSim.build_match(fixture_id: fx.id, result:))
            Repositories::GoalEventRepository.save_batch(GameweekRoundSim.goal_events_for_fixture(fx, result))
            Repositories::FixtureRepository.save(GameweekRoundSim.fixture_played(fx))
            summaries << summary_class.new(fixture: fx, result:)
          end

          def save_league_progress(state)
            gw = state.gameweek
            max_gw = state.max_gw
            lid = state.league.id
            lg = state.league
            Repositories::LeagueRepository.save(
              Domain::League.new(
                id: lid,
                name: lg.name,
                year: lg.year,
                status: gw >= max_gw ? :complete : :active,
                current_gameweek: gw + 1
              )
            )
            Repositories::LeagueRepository.complete!(lid) if gw >= max_gw
          end
        end
      end
    end
  end
end
