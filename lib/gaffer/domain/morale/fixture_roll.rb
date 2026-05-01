# frozen_string_literal: true

require_relative "side_line"

module Gaffer
  module Domain
    module Morale
      module FixtureRoll
        module_function

        def pair_updates(row, rng)
          res = row.result
          hm = SideLine.player_updates(
            xi: row.home_xi,
            goals_for: res.home_score,
            goals_against: res.away_score,
            scorers: res.home_scorers,
            rng: rng
          )
          aw = SideLine.player_updates(
            xi: row.away_xi,
            goals_for: res.away_score,
            goals_against: res.home_score,
            scorers: res.away_scorers,
            rng: rng
          )
          hm.merge(aw)
        end
      end
    end
  end
end
