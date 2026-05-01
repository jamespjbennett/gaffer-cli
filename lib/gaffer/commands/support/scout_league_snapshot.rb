# frozen_string_literal: true

require_relative "../../domain/league_table"
require_relative "../../repositories/fixture_repository"
require_relative "../../repositories/club_repository"

module Gaffer
  module Commands
    module Support
      # Table + settled results for a season (scout dossier reads).
      ScoutLeagueSnapshot =
        Data.define(:clubs, :results, :rows, :positions, :league_size) do
          def self.for_season(league_row_id)
            lid = league_row_id.to_i
            club_ids = Repositories::FixtureRepository.club_ids_for_season(lid)
            clubs = Repositories::ClubRepository.for_ids_ordered(club_ids)
            results = Repositories::FixtureRepository.settled_scores_for_season(lid)
            rows = Domain::LeagueTable.standings_for(clubs:, results: results)
            positions = Domain::LeagueTable.positions_by_club(rows)
            size = clubs.size.positive? ? clubs.size : 1
            new(clubs:, results:, rows:, positions:, league_size: size)
          end

          def row_for_club(cid)
            rows.find { |r| r.club.id.to_i == cid.to_i }
          end

          def slot_for(cid)
            positions[cid.to_i] || league_size
          end
        end
    end
  end
end
