# frozen_string_literal: true

require_relative "coach_training_matrix"

module Gaffer
  module Narratives
    # Rules-based training-ground lines from [`Domain::CoachingContext`] + morale/form matrix.
    module CoachTrainingReport
      STEADY = "Nobody standing out mood-wise midweek — no alarms, nobody in the crisis column.".freeze

      class << self
        def paragraphs(ctx)
          return steady if ctx.nil?
          return steady unless ctx.notable?
          full(ctx)
        end

        private

        def steady
          [STEADY]
        end

        def full(ctx)
          [coach_intro(ctx)] + band(ctx.rising, :rising) + band(ctx.falling, :falling)
        end

        def coach_intro(ctx)
          "Training notes · #{club_label(ctx)} — who looks sharp, who needs a lift."
        end

        def club_label(ctx)
          raw = ctx.managed_club.short_name.to_s.strip
          raw.empty? ? ctx.managed_club.name.to_s : raw
        end

        def band(players, kind)
          return [] if players.empty?
          [pill(kind)] + players.map { CoachTrainingMatrix.sentence_for_band(_1, kind) }
        end

        def pill(kind)
          kind == :rising ? "Sharp in training:" : "Concern:"
        end
      end
    end
  end
end
