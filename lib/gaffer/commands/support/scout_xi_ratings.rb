# frozen_string_literal: true

require_relative "../../domain/lineup"
require_relative "../../repositories/player_repository"

module Gaffer
  module Commands
    module Support
      # Opponent / managed XI attack–defence read (same helper as match engine scouting).
      module ScoutXiRatings
        class << self
          def pair(engine:, club:, squad_club_id:)
            squad = Repositories::PlayerRepository.for_club(squad_club_id.to_i)
            xi = Domain::Lineup.pick_best_xi(squad)
            return [1e-9, 1e-9].map(&:to_f) unless xi.size == 11

            engine.attack_defense_rating_for_xi(club: club, players: xi)
          end
        end
      end
    end
  end
end
