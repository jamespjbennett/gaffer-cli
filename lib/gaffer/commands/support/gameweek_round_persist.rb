# frozen_string_literal: true

require_relative "../../database"
require_relative "../../domain/league"
require_relative "../../domain/morale_round_row"
require_relative "../../domain/morale_updater"
require_relative "../../repositories/league_repository"
require_relative "../../repositories/match_repository"
require_relative "../../repositories/goal_event_repository"
require_relative "../../repositories/player_repository"
require_relative "../../repositories/fixture_repository"
require_relative "gameweek_round_sim"
require_relative "gameweek_tactics"

module Gaffer
  module Commands
    module Support
      # Simulates every fixture in the round and bumps league state inside one DB transaction.
      module GameweekRoundPersist
        class << self
          def run_transaction(state:, manager_shape:, user_xi:, summary_class:, engine:, interactive: nil)
            summaries = []
            mid = state.managed_club_id

            Gaffer::Database.db.transaction do
              players_by_id = players_snapshot(state)
              morale_rows = []
              rng = morale_rng(state)
              state.round_fixtures.each do |fx|
                persist_one_fixture(
                  fx:,
                  state:,
                  mid:,
                  manager_shape:,
                  user_xi:,
                  engine:,
                  summaries:,
                  summary_class:,
                  morale_rows:,
                  interactive:
                )
              end
              apply_morale_rows(morale_rows, players_by_id, rng)
              save_league_progress(state)
            end

            summaries
          end

          private

          def persist_one_fixture(fx:, state:, mid:, manager_shape:, user_xi:, engine:, summaries:, summary_class:, morale_rows:, interactive:)
            if use_canned?(fx, interactive)
              hydrate(fx:, canned: interactive.fetch(:outcome), summaries:, summary_class:, morale_rows:)
              return
            end

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
            out = GameweekRoundSim.simulate_full(plan)
            roll_fixture(
              fx,
              out.result,
              summaries,
              summary_class,
              morale_rows,
              out.morale_home_xi,
              out.morale_away_xi
            )
          end

          def use_canned?(fx, pack)
            pack.is_a?(Hash) &&
              fx.id.to_i == pack[:fixture_id].to_i &&
              pack[:outcome].is_a?(GameweekRoundSim::SimulateOutcome)
          end

          def hydrate(fx:, canned:, summaries:, summary_class:, morale_rows:)
            roll_fixture(
              fx,
              canned.result,
              summaries,
              summary_class,
              morale_rows,
              canned.morale_home_xi,
              canned.morale_away_xi
            )
          end

          def roll_fixture(fx, result, summaries, summary_class, morale_rows, mh, ma)
            Repositories::MatchRepository.save(GameweekRoundSim.build_match(fixture_id: fx.id, result:))
            Repositories::GoalEventRepository.save_batch(GameweekRoundSim.goal_events_for_fixture(fx, result))
            Repositories::FixtureRepository.save(GameweekRoundSim.fixture_played(fx))
            morale_rows <<
              Domain::MoraleRoundRow.new(
                fixture: fx,
                result: result,
                home_xi: mh,
                away_xi: ma
              )
            summaries << summary_class.new(fixture: fx, result: result)
          end

          def players_snapshot(state)
            state.clubs_by_id.keys.flat_map { |cid| Repositories::PlayerRepository.for_club(cid) }.each_with_object({}) do |pl, h|
              h[pl.id] = pl
            end
          end

          def morale_rng(state)
            Random.new(state.league.id.to_i ^ state.gameweek.to_i)
          end

          def apply_morale_rows(morale_rows, players_by_id, rng)
            deltas =
              Domain::MoraleUpdater.call(
                round_fixtures: morale_rows,
                players_by_id: players_by_id,
                rng: rng
              )
            Repositories::PlayerRepository.update_morale_form_batch(deltas)
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
            Repositories::PlayerRepository.increment_age_for_league!(lid) if gw >= max_gw
          end
        end
      end
    end
  end
end
