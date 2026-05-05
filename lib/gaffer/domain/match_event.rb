# frozen_string_literal: true

require_relative "player"

module Gaffer
  module Domain
    # Discrete in-match commentary row (minute-level sim).
    MatchEvent = Data.define(:minute, :side, :type, :player, :description) do
      # side: :home | :away · type: :goal | :big_chance
    end
  end
end
