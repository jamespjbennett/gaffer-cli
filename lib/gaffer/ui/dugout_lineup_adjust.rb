# frozen_string_literal: true

require_relative "../domain/lineup"
require_relative "../presenters/scout_briefing_tty"
require_relative "dugout_lineup_paint"

module Gaffer
  module Ui
    # Slot-change loop + optional scout replay within dugout ([`DugoutLineup`] delegates here).
    module DugoutLineupAdjust
      module_function

      DONE_ROW = { name: "Lineup confirmed — continue", value: :done }.freeze
      VIEW_ROW = { name: "View scout notes", value: :view_scout }.freeze

      def run_loop(sheet, squad, xi, prompt)
        loop do
          pick = prompt.select(sheet.pastel.bold("Adjust your XI"), menu_rows(xi, sheet.scout), cycle: true)
          break if pick == :done
          redo if replay_scout_and_repaint?(sheet, pick, squad, xi, prompt)

          swap_slot(sheet, xi, squad, pick, prompt)
        end
      end

      def menu_rows(xi, scout)
        scout_choice(scout) + [DONE_ROW] + slot_choices(xi)
      end

      def scout_choice(scout)
        scout ? [VIEW_ROW] : []
      end

      def slot_choices(xi)
        Domain::Lineup::XI_SLOT_LABELS.each_with_index.map do |lbl, idx|
          { name: "Change #{lbl} · #{xi[idx].name}", value: idx }
        end
      end

      # @return true if consumed (caller should redo loop)
      def replay_scout_and_repaint?(sheet, pick, squad, xi, prompt)
        return false unless pick == :view_scout

        show_scout_notes(sheet, prompt)
        DugoutLineupPaint.paint_opening(sheet, squad, xi)
        true
      end

      def show_scout_notes(sheet, prompt)
        Presenters::ScoutBriefingTty.replay_dugout(
          sheet.scout,
          pastel: sheet.pastel,
          out: sheet.out,
          coaching: sheet.coaching,
          prompt: prompt
        )
      end

      def swap_slot(sheet, xi, squad, pick, prompt)
        idx = Integer(pick)
        swap_into(xi, idx, squad, prompt, sheet.pastel)
      end

      def swap_into(xi, slot_idx, squad, prompt, pastel)
        want = Domain::Lineup::FORMATION_SLOTS[slot_idx]
        cur = xi[slot_idx]
        pool = rivals(xi, slot_idx, squad, want)
        repl = replacement_menu(slot_idx, want, cur, pool, pastel, prompt)
        xi[slot_idx] = repl
      end

      def rivals(xi, slot_idx, squad, want)
        taken = xi.each_with_index.each_with_object([]) { |(pl, j), ids| ids << pl.id if j != slot_idx }
        pool = squad.reject { |pl| taken.include?(pl.id) }
        fit = pool.select { |pl| pl.position&.to_sym == want }
        fit.empty? ? pool : fit
      end

      def replacement_menu(slot_idx, want, cur, pool, pastel, prompt)
        lbl = Domain::Lineup::XI_SLOT_LABELS[slot_idx]
        rows = [stay_pick(cur)] + sorted_pool(pool, cur).map { |pl| roster_row(pl) }
        prompt.select(pastel.bold("Who wears #{lbl} (#{want.upcase})?"), rows, cycle: true)
      end

      def sorted_pool(pool, cur)
        pool.reject { |pl| pl.id == cur.id }.sort_by { |pl| [-Domain::Lineup.grade_scalar(pl)] }
      end

      def roster_row(pl)
        { name: "#{pl.name}  OVR #{pl.overall}", value: pl }
      end

      def stay_pick(cur)
        { name: "(stay on #{cur.name})", value: cur }
      end
    end
  end
end
