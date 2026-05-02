# frozen_string_literal: true

require_relative "coach_training_matrix"

module Gaffer
  module Narratives
    # Rules-based training-ground lines from [`Domain::CoachingContext`] + morale/form matrix.
    module CoachTrainingReport
      STEADY = "Squad mood's middling midweek — nobody tearing it up or losing the plot.".freeze

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
          "Coach notes · #{club_label(ctx)} — who's sharp, who needs lifting."
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
          kind == :rising ? "On the up:" : "Cause for concern:"
        end
      end
    end
  end
end
