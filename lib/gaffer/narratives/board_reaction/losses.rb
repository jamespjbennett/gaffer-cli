# frozen_string_literal: true

module Gaffer
  module Narratives
    module BoardReaction
      module Losses
        extend self

        def line(ctx)
          PHRASES.fetch(loss_key(ctx)).call(ctx)
        end

        private

        def loss_key(ctx)
          return :battered if ctx.margin >= 3
          return :away_elite_narrow if away_top_narrow?(ctx)
          return :home_weak if home_to_weak_side?(ctx)
          return :slender_away if slender_away?(ctx)
          :default
        end

        def away_top_narrow?(ctx)
          !ctx.hosting_managed && ctx.opponent_strong? && ctx.margin <= 1
        end

        def home_to_weak_side?(ctx)
          ctx.hosting_managed && ctx.opponent_weak?
        end

        def slender_away?(ctx)
          !ctx.hosting_managed && !ctx.opponent_weak? && ctx.margin == 1
        end

        PHRASES = {
          battered: lambda do |_c|
            "Conceded far too cheaply and never looked comfortable. " \
            "Honest debrief required before walking out again."
          end,
          away_elite_narrow: lambda do |_c|
            "Stayed in the contest on a tough ground. Margins were tiny — bottle that fight for the next trip."
          end,
          home_weak: lambda do |_c|
            "No excuses for gifting lifelines at home. They expect far more steel and sharper ideas."
          end,
          slender_away: lambda do |_c|
            "Denied by a thin margin on the road. Take the graft, then sharpen the decisive moments."
          end,
          default: lambda do |_c|
            "Could not tilt the midfield or threaten consistently. Something has to spark before the next whistle."
          end
        }.freeze
      end
    end
  end
end
