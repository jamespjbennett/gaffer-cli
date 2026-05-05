# frozen_string_literal: true

module Gaffer
  module Narratives
    module BoardReaction
      # Shared predicates for Tone + Opening.
      module Vibes
        module_function

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

        def home_weak_loss?(ctx)
          ctx.hosting_managed && ctx.opponent_weak?
        end

        def drawn?(ctx)
          ctx.managed_goals == ctx.opponent_goals
        end
      end
    end
  end
end
