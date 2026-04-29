# frozen_string_literal: true

module Gaffer
  module Domain
    # Lightweight outcome from MatchEngine — no scorer detail yet.
    MatchResult = Data.define(
      :home_score,
      :away_score,
      :home_xg_lambda,
      :away_xg_lambda,
      :home_attack_rating,
      :home_defense_rating,
      :away_attack_rating,
      :away_defense_rating
    )
  end
end
