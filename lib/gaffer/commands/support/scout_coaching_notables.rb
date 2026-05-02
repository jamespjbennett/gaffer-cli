# frozen_string_literal: true

require_relative "../../domain/coaching_context"
require_relative "../../domain/player"

module Gaffer
  module Commands
    module Support
      # Picks rising (form > neutral) vs falling (< neutral) XI members for coaching copy.
      module ScoutCoachingNotables
        NEUTRAL = 5

        module_function

        def context(managed_club:, managed_xi:)
          xi = Array(managed_xi)
          Domain::CoachingContext.new(
            managed_club: managed_club,
            rising: notable_rising(xi),
            falling: notable_falling(xi)
          )
        end

        def notable_rising(xi)
          xi.select { form(_1) > NEUTRAL }.sort_by { |p| rank_rising_pair(p) }.take(3)
        end

        def notable_falling(xi)
          xi.select { form(_1) < NEUTRAL }.sort_by { |p| rank_falling_pair(p) }.take(3)
        end

        def rank_rising_pair(p)
          [-form(p), name_key(p)]
        end

        def rank_falling_pair(p)
          [form(p), name_key(p)]
        end

        def name_key(p)
          p.name.to_s.downcase
        end

        def form(p)
          f = p.form
          f.nil? ? NEUTRAL : f.to_i.clamp(1, 10)
        end
      end
    end
  end
end
