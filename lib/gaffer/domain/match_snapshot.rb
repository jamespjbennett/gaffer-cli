# frozen_string_literal: true

module Gaffer
  module Domain
    # Lightweight view for halftime / FT commentary.
    MatchSnapshot = Data.define(
      :minute,
      :home_score,
      :away_score,
      :home_fatigue,
      :away_fatigue,
      :events,
      :team_stats
    )
  end
end
