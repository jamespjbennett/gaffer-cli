# frozen_string_literal: true

module Gaffer
  module Domain
    # Attribute-weighted random scorers for a side; uses the same RNG sequence as MatchEngine (after Poisson draws).
    module ScorerPicker
      POSITION_MULTIPLIER = {
        att: 2.0,
        mid: 0.8,
        def: 0.25,
        gk: 0.0
      }.freeze

      module_function

      # @param xi [Array<Domain::Player>] starting XI (keeper included; excluded from goal pool)
      # @param n_goals [Integer]
      # @param rng [Random]
      # @return [Array<Domain::Player>] length n_goals (repeats allowed)
      def pick(xi, n_goals, rng)
        n = Integer(n_goals)
        return [] if n <= 0 || xi.nil? || xi.empty?

        pool = xi.reject { |p| p&.position&.to_sym == :gk }
        pool = xi.dup if pool.empty?

        weights = pool.map { |p| raw_weight(p) }
        total = weights.sum
        if total <= 0
          return Array.new(n) { pool[rng.rand(pool.size)] }
        end

        n.times.map { weighted_pick(pool, weights, total, rng) }
      end

      def raw_weight(player)
        pos = player&.position&.to_sym
        mult = POSITION_MULTIPLIER.fetch(pos, 0.4)
        return 0.0 if mult.zero?

        sho = iv(player, :shooting)
        pace = iv(player, :pace)
        drib = iv(player, :dribbling)
        base = (sho * 1.0 + pace * 0.4 + drib * 0.3)
        base * mult
      end
      private_class_method :raw_weight

      def iv(player, attr)
        v = player.public_send(attr)
        v.nil? ? 62 : v.to_i.clamp(1, 99)
      end
      private_class_method :iv

      def weighted_pick(pool, weights, total, rng)
        r = rng.rand * total
        acc = 0.0
        pool.each_with_index do |_pl, i|
          acc += weights[i]
          return pool[i] if r <= acc
        end
        pool.last
      end
      private_class_method :weighted_pick
    end
  end
end
