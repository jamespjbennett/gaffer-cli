# frozen_string_literal: true

require_relative "club"
require_relative "player"

module Gaffer
  module Domain
    # Single slice of XI + tactic + fatigue for minute-level λ recomputation.
    MatchLineupMoment = Data.define(:club, :players, :fatigue, :tactic)
  end
end
