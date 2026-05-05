# frozen_string_literal: true

require_relative "dugout_lineup"
require_relative "../commands/support/gameweek_tactics"

module Gaffer
  module Ui
    # Halftime XI tweak + tactical repick before Minute 46.
    module HalftimeRefresh
      extend self

      def apply(prompt:, pastel:, out:, state:, managed_home:, fx:, shape:, home_xi:, away_xi:)
        hh = home_xi.dup
        aa = away_xi.dup
        hh, aa = redo_xi(prompt, pastel, out, state, managed_home, hh, aa)

        kw = redo_shape(prompt, pastel, out, state, fx, shape)
        tac =
          tactics.tactics_pair_for(
            fixture: fx,
            managed_id: state.managed_club_id,
            shape: kw
          )

        {
          home_xi: hh,
          away_xi: aa,
          home_tactic: tac.first,
          away_tactic: tac.last
        }
      end

      private

      def redo_shape(prompt, pastel, out, state, fx, shape)
        return shape unless prompts?(prompt)
        flip = prompt.yes?("Retune tactic before stepping out again?")
        flip ? halftime_shape(prompt, pastel, out, state, fx) : shape
      end

      def prompts?(prompt)
        prompt&.respond_to?(:yes?) && prompt&.respond_to?(:select)
      end

      def halftime_shape(prompt, pastel, out, state, fx)
        tactics.pick_interactive_shape(
          pastel: pastel,
          out: out,
          prompt: prompt,
          managed_fixture: fx,
          clubs_by_id: state.clubs_by_id,
          managed_club_id: state.managed_club_id
        )
      end

      def redo_xi(prompt, pastel, out, state, mh, hh, aa)
        return [hh, aa] unless prompt&.respond_to?(:yes?)
        return [hh, aa] unless prompt.yes?("Sub or reshuffle XI (second half)?")

        xi = halftime_xi(prompt, pastel, out, state, mh, hh, aa)
        return [hh, aa] unless xi&.size == 11

        merge(mh, xi, hh, aa)
      end

      def merge(managed_home, xi, hh, aa)
        if managed_home
          hh.replace(xi)
        else
          aa.replace(xi)
        end

        [hh, aa]
      end

      def halftime_xi(prompt, pastel, out, state, mh, hh, aa)
        base = mh ? hh : aa

        # Preset skips the dugout whenever it validates (#resolve short-circuit). User already
        # confirmed they want a reshuffle — always run the XI flow with current XI as suggestion.
        Ui::DugoutLineup.resolve(
          preset: nil,
          suggested_xi: base,
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

      def tactics
        Gaffer::Commands::Support::GameweekTactics
      end
    end
  end
end
