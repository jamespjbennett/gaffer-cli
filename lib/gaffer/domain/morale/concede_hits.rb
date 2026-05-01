# frozen_string_literal: true

require_relative "defender_pick"

module Gaffer
  module Domain
    module Morale
      module ConcedeHits
        module_function

        def defender_hits(xi, goals_against, rng)
          defs = xi.select { |pl| pl.position&.to_sym == :def }
          tall = Hash.new(0)
          goals_against.times do
            pl = DefenderPick.weighted_pick(defs, rng) || xi[rng.rand(xi.size)]
            tall[pl.id] += 1 if pl&.id&.to_i&.positive?
          end
          tall
        end
      end
    end
  end
end
