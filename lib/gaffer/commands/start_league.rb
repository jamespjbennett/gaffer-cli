# frozen_string_literal: true

require "pastel"

module Gaffer
  module Commands
    # Create a `{League}` row, attach all clubs, generate and bulk-insert fixtures, then activate the league.
    #
    # @see CLAUDE.md Phase 1b Step 4
    module StartLeague
      DEFAULT_FIRST_YEAR = 2026
      BASE_LEAGUE_NAME = "Fictional League One"

      class << self
        # @return [Symbol] `:ok`, `:skipped_active`, `:no_clubs`, `:bad_club_count`, or `:generation_error`
        def run(pastel: Pastel.new, out: $stdout)
          Gaffer::Database.connect

          return skip_active(pastel, out) if Repositories::LeagueRepository.active

          clubs = Repositories::ClubRepository.all.sort_by(&:name)
          return no_clubs(pastel, out) if clubs.empty?

          club_ids_sorted = clubs.map(&:id).sort
          unless club_ids_sorted.size >= 2 && club_ids_sorted.size.even? && club_ids_sorted.uniq.size == club_ids_sorted.size
            out.puts pastel.red("Cannot start league: need an even number (≥ 2) of distinct clubs.")
            return :bad_club_count
          end

          year = next_calendar_year
          club_name_by_id = clubs.each_with_object({}) { |c, h| h[c.id] = c.name }
          manager = Repositories::ManagerRepository.current

          protos_for_ui = []

          begin
            Gaffer::Database.db.transaction do
              pending = Repositories::LeagueRepository.save(
                Domain::League.new(
                  name: league_label(year),
                  year: year,
                  status: :pending,
                  current_gameweek: 1
                )
              )

              Repositories::ClubRepository.assign_all_to_league!(pending.id)

              protos_for_ui.replace(
                Domain::FixtureGenerator.generate(club_ids: club_ids_sorted, league_id: pending.id)
              )

              Repositories::FixtureRepository.import_new_fixtures!(protos_for_ui)

              Repositories::LeagueRepository.save(
                Domain::League.new(
                  id: pending.id,
                  name: pending.name,
                  year: pending.year,
                  status: :active,
                  current_gameweek: 1
                )
              )
            end
          rescue ArgumentError => e
            out.puts pastel.red("Could not generate fixtures: #{e.message}")
            return :generation_error
          end

          max_gw = protos_for_ui.map(&:gameweek).max
          out.puts pastel.green("Season #{year} is underway.")
          out.puts "Gameweek 1 of #{max_gw}."
          if (opener = gw1_line_for_manager(protos_for_ui, manager, club_name_by_id))
            out.puts pastel.dim(opener)
          end

          :ok
        end

        private

        def skip_active(pastel, out)
          out.puts pastel.red("A league season is already in progress.")
          :skipped_active
        end

        def no_clubs(pastel, out)
          out.puts pastel.red("No clubs in the database — run:")
          out.puts pastel.dim("  bundle exec rake db:seed")
          :no_clubs
        end

        def next_calendar_year
          ly = Repositories::LeagueRepository.latest_year
          ly.nil? ? DEFAULT_FIRST_YEAR : ly + 1
        end

        def league_label(year)
          "#{BASE_LEAGUE_NAME} #{year}"
        end

        def gw1_line_for_manager(protos, manager, club_name_by_id)
          return nil unless manager

          mid = manager.managed_club_id.to_i
          fx = protos.find { |f| f.gameweek == 1 && (f.home_club_id == mid || f.away_club_id == mid) }
          return nil unless fx

          home = club_name_by_id[fx.home_club_id] || "Home"
          away = club_name_by_id[fx.away_club_id] || "Away"
          if fx.home_club_id == mid
            "Your first fixture — #{home} (you) vs #{away}"
          else
            "Your first fixture — #{home} vs #{away} (you)"
          end
        end
      end
    end
  end
end
