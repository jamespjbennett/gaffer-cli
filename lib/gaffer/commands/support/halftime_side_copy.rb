# frozen_string_literal: true

module Gaffer
  module Commands
    module Support
      # Pronoun-aware half-time bullet lines — :managed = "You", :opponent = "Them".
      module HalftimeSideCopy
        module_function

        def chances_big(bc, side)
          n = bc.to_i
          word = n == 1 ? "chance" : "chances"
          return "Created real problems for us — #{n} big #{word}." if foe?(side)

          "Caused real problems — #{n} big #{word} created."
        end

        def possession_good(poss, side)
          p = poss.to_f
          foe?(side) ? "Kept #{p.round(1)}% of the ball — had you penned in." : "Bossing possession at #{p.round(1)}%."
        end

        def goals_positive(st, side)
          g = Integer(st.fetch(:goals, 0))
          return nil unless g.positive?

          goal_hit_copy(g, side)
        end

        def poor_touch(st, side)
          pct = st[:possession].to_f.round(1)
          foe?(side) ? "Starved of the ball (#{pct}%)." : "Struggling for a foothold — only #{pct}% of the ball."
        end

        def low_shots(side)
          foe?(side) ? "Rarely troubled your keeper — hardly a shot." : "Barely got near their goal in the first half."
        end

        def weary_xi(side)
          foe?(side) ? "Their XI looks leggy coming out for the restart." : "A few of your XI look leggy."
        end

        def foe?(side)
          side == :opponent
        end

        def goal_hit_copy(g, side)
          return one_goal_us(g) if foe?(side)

          g == 1 ? "Made it count — on the scoresheet." : "Made it count — #{g} goals to show for it."
        end

        def one_goal_us(g)
          g == 1 ? "Hurt you — 1 goal against you at the break." : "Hurt you — #{g} goals against you at the break."
        end
      end
    end
  end
end
