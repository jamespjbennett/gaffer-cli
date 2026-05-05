# frozen_string_literal: true

require_relative "../../domain/halftime_report"
require_relative "../../domain/player"
require_relative "halftime_side_copy"

module Gaffer
  module Commands
    module Support
      # Halftime narrative from snapshot — rule-based diagnostics only.
      module HalftimeReportBuilder
        FATIGUE_FLAG = 0.48

        extend self

        Slice = Struct.new(:snapshot, :runner, :managed_home, :managed_label, :opponent_label,
          keyword_init: true)

        def from_runner(slice)
          snap = slice.snapshot
          keyed = axis_keys(slice.managed_home)

          Domain::HalftimeReport.new(
            snapshot: snap,
            managed_is_home: slice.managed_home,
            managed_label: tidy(slice.managed_label),
            opponent_label: tidy(slice.opponent_label),
            managed_hot: hotcorner(slice.runner, snap, keyed[:managed_axis]),
            managed_cold: coldcorner(slice.runner, snap, keyed[:managed_axis]),
            opponent_hot: hotcorner(slice.runner, snap, keyed[:opponent_axis]),
            opponent_cold: coldcorner(slice.runner, snap, keyed[:opponent_axis]),
            managed_strength_lines: praise(snap, keyed[:managed_axis], :managed),
            managed_weak_lines: fret(snap, keyed[:managed_axis], :managed),
            opponent_strength_lines: praise(snap, keyed[:opponent_axis], :opponent),
            opponent_weak_lines: fret(snap, keyed[:opponent_axis], :opponent)
          )
        end

        private

        def axis_keys(managed_home)
          { managed_axis: managed_home ? :home : :away, opponent_axis: managed_home ? :away : :home }
        end

        # hotcold returned [max, min] before — split for clarity
        def hotcorner(runner, snap, axis)
          pair = hotcold(runner, snap, axis)
          pair.first
        end

        def coldcorner(runner, snap, axis)
          hotcold(runner, snap, axis).last
        end

        def tidy(txt)
          s = txt.to_s.strip
          s.empty? ? "Side" : s
        end

        def hotcold(runner, snap, axis)
          xi = axis == :home ? runner.home_players : runner.away_players
          ft = axis == :home ? snap.home_fatigue.to_a : snap.away_fatigue.to_a
          return [nil_wire, nil_wire] if xi.empty?

          wired = xi.each_with_index.map { |pl, i| mark(pl, ft, i) }
          [stamp(wired.max_by { |w| w[:score] }), stamp(wired.min_by { |w| w[:score] })]
        end

        def nil_wire
          { player: nil, score: 0.0 }
        end

        def mark(pl, fat, ix)
          flev = fatigue_read(fat, ix)
          scr = mojo(pl) * (1.0 - (0.45 * flev))
          { score: scr, player: pl }
        end

        def stamp(rec)
          { player: rec[:player], score: rec[:score].to_f.round(2) }
        end

        def mojo(pl)
          form_clamp(pl) / 10.0 + morale_idx(pl)
        end

        def morale_idx(pl)
          i = Domain::MORALE_LEVELS.index(pl&.morale&.to_sym)
          (i.nil? ? 2 : i).to_f
        end

        def form_clamp(pl)
          v = pl&.form&.to_i
          return 5 if v.nil?

          v.clamp(1, 10)
        end

        def fatigue_read(arr, ix)
          return 0.0 unless arr

          arr[ix].to_f
        rescue IndexError
          0.0
        end

        def praise(snap, axis, side)
          st = snap.team_stats.fetch(axis)
          lines = perk_lines(st, side)
          lines.compact.take(3)
        end

        def perk_lines(st, side)
          acc = []
          acc << HalftimeSideCopy.chances_big(st[:big_chances], side) if punchy?(st)
          acc << HalftimeSideCopy.possession_good(st[:possession], side) if dom_poss?(st)
          poke_goal(acc, st, side)
          acc
        end

        def poke_goal(acc, st, side)
          g = HalftimeSideCopy.goals_positive(st, side)
          acc << g unless g.nil?
        end

        def dom_poss?(st)
          st[:possession].to_f >= 53.5
        end

        def punchy?(st)
          Integer(st.fetch(:big_chances, 0)) >= 2
        end

        def fret(snap, axis, side)
          st = snap.team_stats.fetch(axis)
          fret_pack(st, snap, axis, side).compact.take(3)
        end

        def fret_pack(st, snap, axis, side)
          w = []
          w << HalftimeSideCopy.poor_touch(st, side) if low_poss?(st)
          w << HalftimeSideCopy.low_shots(side) if few_shots?(st)
          weary_push(w, snap, axis, side)
          w
        end

        def weary_push(w, snap, axis, side)
          w << HalftimeSideCopy.weary_xi(side) if weary?(snap, axis)
        end

        def low_poss?(st)
          st[:possession].to_f < 43.5
        end

        def few_shots?(st)
          st.fetch(:shots, 0).to_i <= 2
        end

        def weary?(snap, axis)
          apex(snap, axis) >= FATIGUE_FLAG
        end

        def apex(snap, axis)
          vec = axis == :home ? snap.home_fatigue.to_a : snap.away_fatigue.to_a
          return 0.0 if vec.empty?

          vec.map(&:to_f).max
        end
      end
    end
  end
end
