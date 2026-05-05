# frozen_string_literal: true

require_relative "../../domain/halftime_report"
require_relative "../../domain/player"

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
          ml = tidy(slice.managed_label)
          ol = tidy(slice.opponent_label)
          m_key = slice.managed_home ? :home : :away
          o_key = slice.managed_home ? :away : :home
          mh, mc = hotcold(slice.runner, snap, m_key)
          oh, oc = hotcold(slice.runner, snap, o_key)

          Domain::HalftimeReport.new(
            snapshot: snap,
            managed_is_home: slice.managed_home,
            managed_label: ml,
            opponent_label: ol,
            managed_hot: mh,
            managed_cold: mc,
            opponent_hot: oh,
            opponent_cold: oc,
            managed_strength_lines: praise(snap, m_key),
            managed_weak_lines: fret(snap, m_key),
            opponent_strength_lines: praise(snap, o_key),
            opponent_weak_lines: fret(snap, o_key)
          )
        end

        private

        def tidy(txt)
          s = txt.to_s.strip
          s.empty? ? "Side" : s
        end

        def hotcold(runner, snap, axis)
          xi = axis == :home ? runner.home_players : runner.away_players
          ft = axis == :home ? snap.home_fatigue.to_a : snap.away_fatigue.to_a
          return [nil_wire, nil_wire] if xi.empty?

          wired = xi.each_with_index.map { |(pl), i| mark(pl, ft, i) }
          mx = wired.max_by { |(w)| w[:score] }
          mn = wired.min_by { |(w)| w[:score] }
          [stamp(mx), stamp(mn)]
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

        def praise(snap, axis)
          st = snap.team_stats.fetch(axis)
          perks = []
          perks << chances_line(st[:big_chances]) if punchy?(st)
          perks << possession_line(st[:possession]) if st[:possession].to_f >= 53.5
          perks << goals_line(st) unless goals_line(st).nil?
          perks.compact.take(3)
        end

        def punchy?(st)
          Integer(st.fetch(:big_chances, 0)) >= 2
        end

        def chances_line(bc)
          "Caused real problems — #{bc} big chance#{'s' unless bc.to_i == 1} created."
        end

        def possession_line(poss)
          "Bossing possession at #{poss}%."
        end

        def goals_line(st)
          g = Integer(st.fetch(:goals, 0))
          return unless g.positive?

          g == 1 ? "Made it count — on the scoresheet." : "Made it count — #{g} goals to show for it."
        end

        def fret(snap, axis)
          st = snap.team_stats.fetch(axis)
          woes = []
          woes << poor_possession_line(st) if st[:possession].to_f < 43.5
          woes << low_shots_line if st.fetch(:shots, 0).to_i <= 2
          woes << tired_line if weary?(snap, axis)
          woes.compact.take(3)
        end

        def poor_possession_line(st)
          "Struggling to get a foothold — only #{st[:possession]}% of the ball."
        end

        def low_shots_line
          "Barely got near their goal in the first half."
        end

        def tired_line
          "A few players will be feeling it — legs starting to go."
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
