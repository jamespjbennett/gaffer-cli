# frozen_string_literal: true

require_relative "../../repositories/goal_event_repository"
require_relative "../../repositories/player_repository"

module Gaffer
  module Commands
    module Support
      # League goal tally filtered to one club — first scorer row wins iteration order from repo.
      module ScoutTopScorerLookup
        class << self
          # @return [Hash, nil] `{ player:, goals: }`
          def for_club(league_id:, opponent_club_id:)
            totals = Repositories::GoalEventRepository.totals_by_player(league_id)
            cid = opponent_club_id.to_i

            totals.each do |row|
              pl = Repositories::PlayerRepository.find(row[:player_id])
              next unless pl
              next unless pl.club_id.to_i == cid

              return { player: pl, goals: row[:goals].to_i }
            end

            nil
          end
        end
      end
    end
  end
end
