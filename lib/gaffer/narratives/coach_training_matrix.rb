# frozen_string_literal: true

require_relative "../domain/player"

module Gaffer
  module Narratives
    # Rows: Domain::MORALE_LEVELS (unhappy→ecstatic). Columns: form 1-2 … 9-10.
    module CoachTrainingMatrix
      module_function

      def sentence(player)
        cheer_sentence(player)
      end

      def sentence_for_band(player, kind)
        kind == :rising ? cheer_sentence(player) : worry_sentence(player)
      end

      def cheer_sentence(player)
        format(cell(player), name: player.name.to_s)
      end

      def worry_sentence(player)
        format(worry_pick(player), name: player.name.to_s)
      end

      def worry_pick(player)
        bucket = goalie?(player) ? GK_WORRY : FIELD_WORRY
        bucket.fetch(form_i(player))
      end

      def goalie?(player)
        player.position&.to_sym == :gk
      end

      def cell(player)
        TABLE[mor_i(player)][form_i(player)]
      end

      def mor_i(player)
        Domain::MORALE_LEVELS.index(player.morale&.to_sym) || 2
      end

      def form_i(player)
        f = player.form.nil? ? 5 : player.form.to_i.clamp(1, 10)
        case f when 1..2 then 0 when 3..4 then 1 when 5..6 then 2 when 7..8 then 3 else 4 end
      end

      TABLE = [
        [ # unhappy
          "%{name} looks well off it — miles from his best in training.",
          "%{name}'s quiet on the ball — touch heavy, mind elsewhere.",
          "%{name} looks like he's going through the motions; needs a proper chat.",
          "%{name}'s flat — confidence is low.",
          "%{name}'s on edge in drills — snappy with teammates, loses focus."
        ],
        [ # unsettled
          "%{name} flashes quality then drops right out of it.",
          "%{name} drifts in and out — still not settled on a role.",
          "%{name}'s decent in spells but slack when we step up the press.",
          "%{name} rushes it under pressure and picks the wrong pass.",
          "%{name}'s keen but loose — needs tightening up before matchday."
        ],
        [ # okay
          "%{name}'s steady — nothing flashy, gets the job done.",
          "%{name}'s where he should be but looks a yard short.",
          "%{name}'s reliable in the shape — same level as last week.",
          "%{name}'s alert; training matches what's on the board.",
          "%{name}'s bright — dragging the tempo of the session."
        ],
        [ # happy
          "%{name}'s walking into challenges with real belief.",
          "%{name}'s linking cleanly with the forwards.",
          "%{name}'s first touch is clean and he's talking the side through it.",
          "%{name}'s on the front foot — others are feeding off him.",
          "%{name}'s reading the press early and setting the runs."
        ],
        [ # ecstatic
          "%{name}'s running the show in the small-sided games.",
          "%{name}'s a handful every time he's on the ball in training.",
          "%{name}'s sharp and seeing passes before they open up.",
          "%{name}'s in top form — confident, disciplined, leading by example.",
          "%{name}'s flying; the staff have been impressed with him this week."
        ]
      ].freeze

      FIELD_WORRY = [
        "%{name} looks a step off — not getting close enough in drills.",
        "%{name}'s sluggish — first touch lets him down in tight areas.",
        "%{name}'s patchy and the urgency has dipped.",
        "%{name} needs to find another gear compared to usual.",
        "%{name}'s not matching the tempo — too loose on the ball."
      ].freeze

      GK_WORRY = [
        "%{name}'s tentative on crosses — late off his line.",
        "%{name}'s kicking has been sloppy in training.",
        "%{name}'s fine with shot-stoppers but not commanding his box.",
        "%{name}'s safe with gloves on but careless with the ball at his feet.",
        "%{name}'s too quiet organising the defenders in front of him."
      ].freeze
    end
  end
end
