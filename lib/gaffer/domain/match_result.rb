# frozen_string_literal: true

module Gaffer
  module Domain
    # Outcome from MatchEngine: scoreline, λ diagnostics, and sampled goal scorers per side.
    MatchResult = Data.define(
      :home_score,
      :away_score,
      :home_xg_lambda,
      :away_xg_lambda,
      :home_attack_rating,
      :home_defense_rating,
      :away_attack_rating,
      :away_defense_rating,
      :home_scorers,
      :away_scorers
    )
  end
end
