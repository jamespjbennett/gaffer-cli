# frozen_string_literal: true

module Gaffer
  module Narratives
    module BoardReaction
      module Wins
        extend self

        def line(ctx)
          PHRASES.fetch(win_key(ctx)).call(ctx)
        end

        private

        def win_key(ctx)
          return :hefty if ctx.margin >= 3
          return :away_elite if away_top?(ctx)
          win_tail(ctx)
        end

        def win_tail(ctx)
          return :handsome if ctx.margin >= 2
          return :scrape if soft_home_scrub?(ctx)
          :default
        end

        def away_top?(ctx)
          !ctx.hosting_managed && ctx.opponent_strong?
        end

        def soft_home_scrub?(ctx)
          ctx.margin == 1 && ctx.hosting_managed && ctx.opponent_weak?
        end

        PHRASES = {
          hefty: lambda do |c|
            next "#{c.managed_goals}-nil and barely looked troubled at the back — excellent." if c.opponent_goals.zero?

            "#{c.managed_goals}-#{c.opponent_goals} — ruthless going forward."
          end,
          away_elite: lambda do |c|
            "#{c.managed_goals}-#{c.opponent_goals} away against top-table opposition."
          end,
          handsome: ->(_c) { "Strong win. Deserved the margin on the day." },
          scrape: lambda do |_c|
            "Three points banked — now raise the tempo in the final third before anyone gets comfortable."
          end,
          default: lambda do |_c|
            "Solid shift all over the pitch. Keep standards high on the training ground this week."
          end
        }.freeze
      end
    end
  end
end
