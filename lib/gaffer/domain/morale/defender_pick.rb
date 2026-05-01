# frozen_string_literal: true

module Gaffer
  module Domain
    module Morale
      module DefenderPick
        module_function

        def weighted_pick(defenders, rng)
          return nil if defenders.empty?

          weights = defenders.map { |pl| concede_weight(pl.defending.to_i.clamp(1, 99)) }
          dart = rng.rand * weights.sum
          walk_dart(defenders, weights, dart)
        end

        module_function

        def concede_weight(def_rating)
          100.0 / (def_rating + 1)
        end

        def walk_dart(defenders, weights, dart)
          acc = 0.0
          defenders.each_with_index do |pl, idx|
            acc += weights[idx]
            return pl if dart < acc
          end
          defenders.last
        end
      end
    end
  end
end
