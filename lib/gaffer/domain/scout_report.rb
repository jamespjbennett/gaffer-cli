# frozen_string_literal: true

require_relative "club"
require_relative "player"

module Gaffer
  module Domain
    # Derived pre-match dossier — standings, XI ratings, watcher target; conversational layer reads this only.
    ScoutReport = Data.define(
      :opponent,
      :managed_club,
      :gameweek,
      :hosting_managed,
      :league_position,
      :league_size,
      :played,
      :manager_league_position,
      :manager_played,
      :manager_points,
      :opponent_points,
      :recent_form,
      :attack_rating,
      :defence_rating,
      :our_attack_rating,
      :our_defence_rating,
      :top_scorer,
      :watch_focus
      # watch_focus: { player:, kind: (:scorer | :livewire | :enforcer), goals: Integer or nil }
    )
  end
end
