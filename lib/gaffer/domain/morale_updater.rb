# frozen_string_literal: true

require_relative "morale/fixture_roll"
require_relative "morale/form_norm"

module Gaffer
  module Domain
    # Post-round morale + form for every XI (all clubs).
    module MoraleUpdater
      module_function

      # @return [Hash{Integer=>{form:, morale:}}]
      def call(round_fixtures:, players_by_id:, rng: Random.new)
        deltas = rollup(round_fixtures, rng)
        filter_changes(deltas, players_by_id)
      end

      def rollup(round_fixtures, rng)
        round_fixtures.each_with_object({}) do |row, memo|
          Morale::FixtureRoll.pair_updates(row, rng).each { |(k, v)| memo[k] = v }
        end
      end

      def filter_changes(deltas, players_by_id)
        deltas.each_with_object({}) do |(id, vals), memo|
          memo[id] = vals if differs?(players_by_id[id], vals)
        end
      end

      def differs?(base, vals)
        return true unless base

        form_differs?(base, vals) || morale_differs?(base, vals)
      end

      def form_differs?(base, vals)
        Morale::FormNorm.clamped(base) != vals[:form].to_i
      end

      def morale_differs?(base, vals)
        (base.morale&.to_sym || :okay) != vals[:morale].to_sym
      end
    end
  end
end
