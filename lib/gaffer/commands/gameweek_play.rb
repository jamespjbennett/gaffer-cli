# frozen_string_literal: true

require_relative "../domain/match_engine"
require_relative "support/scout_report_builder"
require_relative "support/gameweek_preflight"
require_relative "support/gameweek_tactics"
require_relative "support/gameweek_round_persist"
require_relative "support/interactive_league_match"
require_relative "support/gameweek_round_tty"
require_relative "../ui/dugout_lineup"
require_relative "../presenters/scout_briefing_tty"

module Gaffer
  module Commands
    # One full league round: validate schedule and squads, scout → dugout → tactic,
    # simulate and persist every fixture in the gameweek, then post-round TTY and
    # optional next-season offer. Assumes SQLite is already connected (and migrated).
    #
    # Implementation is split across [`Support::GameweekPreflight`], [`Support::GameweekRoundPersist`],
    # [`Support::GameweekRoundTty`], [`Support::GameweekRoundSim`] (parameter object),
    # and [`Support::GameweekTactics`].
    module GameweekPlay
      Summary = Struct.new(:fixture, :result, keyword_init: true)

      class << self
        # @param pastel [Pastel]
        # @param out [IO]
        # @param prompt [#yes?, #select, nil] interactive TTY from the menu where available.
        # @param manager_tactic [Symbol, nil] when set (e.g. tests), skips the tactic menu and uses this shape.
        # @param manager_lineup [Array<Domain::Player>, nil] eleven players from your club to skip dugout UI & validation
        # @return [Symbol] `:ok`, `:no_active_league`, `:no_manager`, `:squads_incomplete`,
        #   `:fixture_data_error`, or `:season_completed`
        def run(pastel:, out:, prompt: nil, manager_tactic: nil, manager_lineup: nil)
          state_or_status = Support::GameweekPreflight.call(pastel:, out:, prompt:)
          return state_or_status if state_or_status.is_a?(Symbol)

          play_round(
            pastel:,
            out:,
            prompt:,
            manager_tactic:,
            manager_lineup:,
            state: state_or_status
          )
        rescue KeyError => e
          out.puts pastel.red("Squads incomplete for this gameweek (#{e.message}). Run db:seed.")
          :squads_incomplete
        end

        private

        def play_round(pastel:, out:, prompt:, manager_tactic:, manager_lineup:, state:)
          present_scouting(pastel:, out:, prompt:, state:)

          xi = dugout_selection(manager_lineup:, prompt:, pastel:, out:, state:)
          unless xi&.size == 11
            out.puts pastel.red("Pick a legal XI (11 outfield + keeper distribution) before kicking off.")
            return :squads_incomplete
          end

          shape = tactic_for_manager(
            manager_tactic:, prompt:, pastel:, out:, state:
          )

          summaries = simulate_and_save(state:, xi:, shape:, pastel:, out:, prompt:)

          finalize_ui(pastel:, out:, prompt:, state:, summaries:, manager_shape: shape)
          state.gameweek >= state.max_gw ? :season_completed : :ok
        end

        def present_scouting(pastel:, out:, prompt:, state:)
          scout =
            Support::ScoutReportBuilder.build(
              opponent_club: state.opponent_club,
              managed_club: state.managed_club,
              league_id: state.league.id,
              gameweek: state.gameweek,
              hosting_managed: state.hosting_managed
            )
          coaching =
            Support::ScoutReportBuilder.build_coaching_context(
              managed_club: state.managed_club,
              managed_xi: state.suggested_xi
            )

          Presenters::ScoutBriefingTty.present(scout, coaching:, pastel:, out:, prompt:)
        end

        def dugout_selection(manager_lineup:, prompt:, pastel:, out:, state:)
          Ui::DugoutLineup.resolve(
            preset: manager_lineup,
            suggested_xi: state.suggested_xi,
            full_squad: state.full_squad,
            club: state.managed_club,
            prompt: prompt,
            pastel: pastel,
            out: out,
            gameweek: state.gameweek,
            opponent: state.opponent_name_short,
            hosting: state.hosting_managed
          )
        end

        def tactic_for_manager(manager_tactic:, prompt:, pastel:, out:, state:)
          Support::GameweekTactics.resolve_manager_shape(
            manager_tactic: manager_tactic,
            prompt: prompt,
            pastel: pastel,
            out: out,
            managed_fixture: state.managed_next,
            clubs_by_id: state.clubs_by_id,
            managed_club_id: state.managed_club_id
          )
        end

        def simulate_and_save(state:, xi:, shape:, pastel:, out:, prompt:)
          engine = Domain::MatchEngine.new
          pack =
            interactive_payload(
              prompt: prompt,
              state: state,
              xi: xi,
              shape: shape,
              pastel: pastel,
              out: out,
              engine: engine
            )
          Support::GameweekRoundPersist.run_transaction(
            state: state,
            manager_shape: shape,
            user_xi: xi,
            summary_class: Summary,
            engine: engine,
            interactive: pack
          )
        end

        def interactive_payload(prompt:, state:, xi:, shape:, pastel:, out:, engine:)
          return unless prompt.respond_to?(:keypress)

          Support::InteractiveLeagueMatch.bundle(
            state: state,
            user_xi: xi,
            manager_shape: shape,
            pastel: pastel,
            out: out,
            prompt: prompt,
            engine: engine,
            interactive: true
          )
        end

        def finalize_ui(pastel:, out:, prompt:, state:, summaries:, manager_shape:)
          final_round = state.gameweek >= state.max_gw
          Support::GameweekRoundTty.print_after_round(
            pastel,
            out,
            summaries: summaries,
            managed_club_id: state.managed_club_id,
            clubs_by_id: state.clubs_by_id,
            gameweek: state.gameweek,
            league: state.league,
            final_round: final_round,
            manager_shape: manager_shape
          )
          Support::GameweekRoundTty.offer_next_season(league: state.league, pastel:, out:, prompt:) if final_round
        end
      end
    end
  end
end
