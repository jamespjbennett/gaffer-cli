# frozen_string_literal: true

module Gaffer
  module Narratives
    module BoardReaction
      module Tone
        extend self

        def apply(core, ctx)
          mood = ctx.managed_club.chairman_mood&.to_sym
          pfx = prefix(mood, vibe(ctx))
          "#{pfx}#{core}"
        end

        private

        def vibe(ctx)
          return :bright if bright_win?(ctx)
          return :grim if grim_loss?(ctx)
          return :soft if forgiving_loss?(ctx) && ctx.managed_loss?
          return :flat if tepid_draw?(ctx)
          :neutral
        end

        def bright_win?(ctx)
          ctx.managed_win? && (ctx.margin >= 3 || upset_win?(ctx))
        end

        def upset_win?(ctx)
          !ctx.hosting_managed && ctx.opponent_strong?
        end

        def grim_loss?(ctx)
          return false unless ctx.managed_loss?

          !(forgiving_loss?(ctx) || narrow_loss_mid?(ctx))
        end

        def forgiving_loss?(ctx)
          ctx.opponent_strong? && !ctx.hosting_managed && ctx.margin <= 1
        end

        def narrow_loss_mid?(ctx)
          ctx.margin <= 1 && !ctx.hosting_managed && !ctx.opponent_weak?
        end

        def tepid_draw?(ctx)
          drawn?(ctx) && ctx.hosting_managed && ctx.opponent_weak?
        end

        def drawn?(ctx)
          ctx.managed_goals == ctx.opponent_goals
        end

        def prefix(mood, vibe_key)
          return "" if mood.nil?

          RULES.fetch(mood, {}).fetch(vibe_key, RULES.fetch(mood, {}).fetch(:neutral, ""))
        end

        RULES = {
          delighted: {
            neutral: "",
            bright: "Brilliant afternoon — ",
            soft: "",
            flat: "",
            grim: ""
          },
          satisfied: {
            neutral: "",
            bright: "",
            soft: "",
            flat: "",
            grim: ""
          },
          concerned: {
            neutral: "",
            bright: "",
            soft: "",
            flat: "We hoped for sharper work — ",
            grim: "Worrying signs — "
          },
          furious: {
            neutral: "",
            bright: "",
            soft: "",
            flat: "Not what we pay for — ",
            grim: "Completely unacceptable — "
          }
        }.freeze
      end
    end
  end
end
