# frozen_string_literal: true

module Gaffer
  module Domain
    # One persisted gameweek row for morale rollup (fixture + XI + simulated result).
    MoraleRoundRow = Data.define(:fixture, :result, :home_xi, :away_xi)
  end
end
