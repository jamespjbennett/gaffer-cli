# frozen_string_literal: true

require_relative "../../domain/match_runner"
require_relative "../../presenters/interactive_match_tty"
require_relative "../../ui/halftime_refresh"
require_relative "gameweek_round_sim"
require_relative "gameweek_tactics"
require_relative "halftime_report_builder"

module Gaffer
  module Commands
    module Support
      # Drives halftime UI + canned outcome for persistence (managed GW tie only).
      module InteractiveLeagueMatch
        class << self
          # @return [Hash] `{ fixture_id:, outcome: GameweekRoundSim::SimulateOutcome }`
          def bundle(state:, user_xi:, manager_shape:, pastel:, out:, prompt:, engine:, interactive: false)
            return unless interactive && prompt&.respond_to?(:keypress)

            fx = state.managed_next
            mid = state.managed_club_id.to_i
            mh = fx.home_club_id.to_i == mid
            ht, at = GameweekTactics.tactics_pair_for(fixture: fx, managed_id: mid, shape: manager_shape)
            seed = fx.id.to_i ^ state.gameweek.to_i
            plan_seed =
              GameweekRoundSim::Plan.new(
                fixture: fx,
                clubs_by_id: state.clubs_by_id,
                engine: engine,
                seed: seed,
                home_tactic: ht,
                away_tactic: at,
                managed_club_id: mid,
                managed_xi: user_xi
              )
            picks = GameweekRoundSim.picked_lineups_for(plan_seed)
            hc = state.clubs_by_id.fetch(fx.home_club_id)
            ac = state.clubs_by_id.fetch(fx.away_club_id)
            run = Domain::MatchRunner.new(
              home_club: hc,
              away_club: ac,
              home_players: picks.first,
              away_players: picks.last,
              home_tactic: ht,
              away_tactic: at,
              seed: seed,
              engine: engine
            )
            first = run.play_to_minute(45)
            Presenters::InteractiveMatchTty.first_half(run, first, pastel:, out:, prompt:)
            halftime_sheet(run, first, state, mh, pastel, out, prompt)
            refresh = halftime_refresh(prompt, pastel, out, state, mh, fx, manager_shape,
              run.home_players.dup,
              run.away_players.dup)
            run.apply_second_half!(
              home_xi: refresh[:home_xi],
              away_xi: refresh[:away_xi],
              home_tactic: refresh[:home_tactic],
              away_tactic: refresh[:away_tactic]
            )
            second = run.play_to_minute(90)
            Presenters::InteractiveMatchTty.second_half(second, runner: run, pastel:, out:, prompt:)
            res = run.finalize_match_result
            Presenters::InteractiveMatchTty.full_time_banner(res, pastel:, out:, prompt:)
            outcome =
              GameweekRoundSim::SimulateOutcome.new(
                result: res,
                home_xi: run.home_players,
                away_xi: run.away_players,
                opening_home_xi: run.opening_home_players,
                opening_away_xi: run.opening_away_players
              )
            { fixture_id: fx.id.to_i, outcome: outcome }
          end

          def halftime_sheet(run, snap, state, mh, pastel, out, prompt)
            report =
              HalftimeReportBuilder.from_runner(
                HalftimeReportBuilder::Slice.new(
                  snapshot: snap,
                  runner: run,
                  managed_home: mh,
                  managed_label: label(state, mh),
                  opponent_label: label(state, !mh)
                )
              )
            Presenters::InteractiveMatchTty.halftime_board(report, pastel:, out:, prompt:)
          end

          def label(state, mine)
            c = mine ? state.managed_club : state.opponent_club
            s = c.short_name.to_s.strip
            return c.name.to_s.strip if s.empty?

            "#{c.name.to_s.strip} (#{s})"
          end

          def halftime_refresh(prompt, pastel, out, state, mh, fx, shape, hp, ap)
            Ui::HalftimeRefresh.apply(
              prompt: prompt,
              pastel: pastel,
              out: out,
              state: state,
              managed_home: mh,
              fx: fx,
              shape: shape,
              home_xi: hp,
              away_xi: ap
            )
          end
        end
      end
    end
  end
end
