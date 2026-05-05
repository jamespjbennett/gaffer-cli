# frozen_string_literal: true

require_relative "vibes"

module Gaffer
  module Narratives
    module BoardReaction
      # Chairman mood flake before the Opening paragraph; analytical lines stay untouched.
      module Tone
        extend self

        def lede(ctx)
          mood = ctx.managed_club.chairman_mood&.to_sym
          return "" if mood.nil?

          RULES.fetch(mood, {}).fetch(tag(ctx), "")
        end

        def apply(core, _ctx)
          core.to_s.strip
        end

        private

        def tag(ctx)
          return :bright if Vibes.bright_win?(ctx)
          return :grim if Vibes.grim_loss?(ctx)
          return :soft if forgiving_loss_tag?(ctx)
          return :flat if Vibes.tepid_draw?(ctx)
          :neutral
        end

        def forgiving_loss_tag?(ctx)
          ctx.managed_loss? && Vibes.forgiving_loss?(ctx)
        end

        RULES = {
          delighted: {
            neutral: "",
            bright: "Brilliant news — ",
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
            flat: "",
            grim: "Worrying signs — "
          },
          furious: {
            neutral: "",
            bright: "",
            soft: "",
            flat: "",
            grim: "Completely unacceptable — "
          }
        }.freeze
      end
    end
  end
end
