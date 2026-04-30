# frozen_string_literal: true

require "tty-table"

module Gaffer
  module Presenters
    # Full standings grid via tty-table (CLAUDE.md Step 6).
    module LeagueTableTty
      HEADER = ["Pos", "Club", "P", "W", "D", "L", "GF", "GA", "GD", "Pts"].freeze

      module_function

      # Hydrates roster from fixtures for `season_id` (covers archived leagues whose `clubs.league_id`
      # advanced to a newer season), then renders via {#render}.
      # @see CLAUDE.md Phase 1b Steps 6–7
      def render_for_season(league_id:, pastel:, managed_club_id: nil)
        lid = league_id.to_i
        ids = Gaffer::Repositories::FixtureRepository.club_ids_for_season(lid)
        clubs = Gaffer::Repositories::ClubRepository.for_ids_ordered(ids)

        unless ids.empty?
          expected = ids.size
          if clubs.size < expected
            return pastel.dim("(#{expected - clubs.size} clubs missing from the database — standings incomplete.)")
          end
        end

        results = Gaffer::Repositories::FixtureRepository.settled_scores_for_season(lid)
        rows = Gaffer::Domain::LeagueTable.standings_for(clubs: clubs, results: results)
        positions = Gaffer::Domain::LeagueTable.positions_by_club(rows)

        render(pastel:, rows:, positions_by_club: positions, managed_club_id: managed_club_id)
      end

      # @param rows [Array<Domain::TableRow>] already sorted standings
      # @param positions_by_club [Hash{Integer=>Integer}]
      # @param managed_club_id [Integer, nil]
      # @return [String]
      def render(pastel:, rows:, positions_by_club:, managed_club_id: nil)
        return pastel.dim("(no clubs in this league)") if rows.nil? || rows.empty?

        mid = managed_club_id&.to_i
        emphasize = mid.positive?

        header_cells = HEADER.map { |label| pastel.bold.white(label.to_s) }

        data_rows =
          rows.map do |row|
            pos = positions_by_club.fetch(row.club.id)
            base = [
              pos,
              row.club.name.to_s,
              row.played,
              row.won,
              row.drawn,
              row.lost,
              row.gf,
              row.ga,
              row.gd,
              row.points
            ]
            if emphasize && row.club.id.to_i == mid
              base.map { |cell| pastel.bold.cyan(cell.to_s) }
            else
              base.map(&:to_s)
            end
          end

        tbl = TTY::Table.new(header: header_cells, rows: data_rows)

        tbl.render(:unicode, multiline: true)
      end
    end
  end
end
