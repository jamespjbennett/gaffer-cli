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
          battered: ->(_c) { "Heavy defeat — regroup quickly." },
          away_elite_narrow: ->(_c) { "Narrow loss away to a leading side." },
          home_weak: ->(_c) { "Lost at home to a struggling outfit." },
          slender_away: ->(_c) { "One-nil away on a tricky pitch." },
          default: ->(_c) { "Could not get anything from this one." }
        }.freeze
      end
    end
  end
end
