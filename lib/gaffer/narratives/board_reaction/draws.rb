# frozen_string_literal: true

module Gaffer
  module Narratives
    module BoardReaction
      module Draws
        extend self

        def line(ctx)
          PHRASES.fetch(draw_key(ctx)).call(ctx)
        end

        private

        def draw_key(ctx)
          return :away_elite if away_top?(ctx)
          return :home_minnow if home_bottom?(ctx)
          return :edge_lost if ctx.hosting_managed && ctx.we_above_them_in_table?
          return :ground_gain if ctx.they_above_us_in_table?
          :midtable
        end

        def away_top?(ctx)
          !ctx.hosting_managed && ctx.opponent_strong?
        end

        def home_bottom?(ctx)
          ctx.hosting_managed && ctx.opponent_weak?
        end

        PHRASES = {
          away_elite: lambda do |_c|
            "Those away points underline real character. Carry that belief into preparation."
          end,
          home_minnow: lambda do |_c|
            "Supporters rightly expect bolder ideas at home. Address it quickly behind closed doors."
          end,
          edge_lost: lambda do |_c|
            "Dropped two points at home despite sitting above them in the table."
          end,
          ground_gain: lambda do |_c|
            "Fair point against a side ahead of us in the standings."
          end,
          midtable: lambda do |c|
            "#{c.managed_goals}-#{c.opponent_goals} — honours even."
          end
        }.freeze
      end
    end
  end
end
