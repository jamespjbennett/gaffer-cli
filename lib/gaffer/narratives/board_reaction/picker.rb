# frozen_string_literal: true

module Gaffer
  module Narratives
    module BoardReaction
      class Picker
        def initialize(ctx)
          @ctx = ctx
        end

        def call
          [Opening.block(ctx), Tone.apply(core_message, ctx)].reject(&:empty?).join("\n\n")
        end

        private

        attr_reader :ctx

        def core_message
          return Wins.line(ctx) if ctx.managed_win?
          return Losses.line(ctx) if ctx.managed_loss?
          Draws.line(ctx)
        end
      end
    end
  end
end
