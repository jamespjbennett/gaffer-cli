# frozen_string_literal: true

module Gaffer
  module Commands
    module Support
      # Immutable bag of everything validated before scout / dugout / sim.
      GameweekPlayState = Data.define(
        :league,
        :managed_club_id,
        :clubs_by_id,
        :managed_next,
        :gameweek,
        :round_fixtures,
        :max_gw,
        :full_squad,
        :suggested_xi,
        :managed_club,
        :opponent_club,
        :opponent_name_short,
        :hosting_managed
      )
    end
  end
end
