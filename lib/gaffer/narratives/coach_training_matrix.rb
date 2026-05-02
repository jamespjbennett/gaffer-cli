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
          "%{name} looks completely out of sorts — brittle in every drill.",
          "%{name}'s withdrawn; touch is heavy and concentration's shot.",
          "%{name} going through motions — nowhere near settled.",
          "%{name} flat despite trying; confidence looks paper-thin.",
          "%{name}'s edgy — snapping at mates, not syncing with shape."
        ],
        [ # unsettled
          "%{name}'s twitchy — good moments then switches off altogether.",
          "%{name} drifting in and out — coach can't nail down a role yet.",
          "%{name} okay in patches but sloppy when pressed.",
          "%{name} eager but rushed; picks wrong option under pressure.",
          "%{name}'s bubbling but loose — needs sharpening before Saturday."
        ],
        [ # okay
          "%{name}'s ticking over — steady, nothing flashy.",
          "%{name}'s alright; knows the patterns, just lacks zip.",
          "%{name} reliable as ever in the shape — same pace as last week.",
          "%{name} sharp enough; training matches what we ask on the board.",
          "%{name}'s bright — training ground energy lifting the group."
        ],
        [ # happy
          "%{name}'s chirpy — stepping into duels with a grin.",
          "%{name}'s bouncing; link play with the tens looks crisp.",
          "%{name}'s dialled in — first touch snapping, voice on the pitch.",
          "%{name}'s flying; others are piggybacking on their tempo.",
          "%{name}'s a step ahead — calling runs before the whistle goes."
        ],
        [ # ecstatic
          "%{name}'s untouchable in rondos — sheer menace this week.",
          "%{name}'s purring; every corridor run opens the defence.",
          "%{name}'s in that rare groove — body loose, radar on.",
          "%{name}'s thriving — swagger without sloppiness, leaders follow them.",
          "%{name}'s red-hot — real buzz about them, coaching staff grinning."
        ]
      ].freeze

      # Cause-for-concern: form band only — avoids “happy morale + low form” sounding upbeat.
      FIELD_WORRY = [
        "%{name}'s flat — chasing shadows when the whistle goes.",
        "%{name}'s off the pace; first touch betraying them in tight spaces.",
        "%{name}'s patchy — shape's there but urgency's dipped.",
        "%{name}'s coasting compared to usual; staff want more edge.",
        "%{name}'s not matching the group's tempo — drifting in possession."
      ].freeze

      GK_WORRY = [
        "%{name}'s nervy coming for crosses — feet stuck, timing late.",
        "%{name}'s distribution's sloppy; same lapse twice in drills.",
        "%{name}'s positionally fine but command's waned — not organising the box.",
        "%{name}'s save-hand sharp but kicking's gifting cheap turnovers.",
        "%{name}'s quiet between the sticks — not driving the tempo from the back."
      ].freeze
    end
  end
end
