# frozen_string_literal: true

require_relative "../../domain/match_engine"

module Gaffer
  module Commands
    module Support
      # Validated inputs for [`ScoutReportBuilder.build`] — one object instead of many keyword params.
      ScoutBuildInput =
        Data.define(:opponent_club, :managed_club, :league_id, :gameweek, :hosting_managed, :engine) do
          def self.from_build_kwargs(opponent_club:, managed_club:, league_id:, gameweek:, hosting_managed:, engine: nil)
            new(
              opponent_club:,
              managed_club:,
              league_id: league_id,
              gameweek: Integer(gameweek),
              hosting_managed: !!hosting_managed,
              engine: engine || Domain::MatchEngine.new
            )
          end

          def validate!
            guard_clubs
            guard_positive_club_ids
            guard_positive_league
            self
          end

          def opponent_id = opponent_club.id.to_i

          def managed_id = managed_club.id.to_i

          def season_id = league_id.to_i

          private

          def guard_clubs
            raise ArgumentError, "opponent_club required" unless opponent_club
            raise ArgumentError, "managed_club required" unless managed_club
          end

          def guard_positive_club_ids
            raise ArgumentError, "club id blank" unless opponent_id.positive? && managed_id.positive?
          end

          def guard_positive_league
            raise ArgumentError, "league_id blank" unless season_id.positive?
          end
        end
    end
  end
end
