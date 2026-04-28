# frozen_string_literal: true

module Gaffer
  module Domain
    # events: array of serialisable hashes (goals, cards, subs, etc.)
    # player_ratings: { Integer => Integer } (player id => rating)
    Match = Struct.new(
      :id,
      :fixture_id,
      :home_score,
      :away_score,
      :home_possession,
      :home_shots,
      :home_shots_ot,
      :away_shots,
      :away_shots_ot,
      :events,
      :player_ratings,
      :narrative,
      keyword_init: true
    )
  end
end
