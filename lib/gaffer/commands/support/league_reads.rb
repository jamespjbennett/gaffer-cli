# frozen_string_literal: true

require_relative "../league_standings"
require_relative "../season_fixtures"
require_relative "../top_scorers"

module Gaffer
  module Commands
    module Support
      # Single entry seams for standings / fixtures / top scorers so Thor and [`Ui::Menu`] stay aligned
      # (`SeasonLookup`, same kwargs shape, shared archived-season picker copy).
      module LeagueReads
        class << self
          # --- CLI (`gaffer table|fixtures|scorers`) ---------------------------------

          # @param year [Integer, String, nil] coerced with +Integer+ when present
          def from_cli_standings(pastel:, out:, previous: false, year: nil)
            LeagueStandings.run(pastel:, out:, previous:, year: coerce_cli_year(year))
          end

          def from_cli_fixtures(pastel:, out:, previous: false, year: nil)
            SeasonFixtures.run(pastel:, out:, previous:, year: coerce_cli_year(year))
          end

          def from_cli_scorers(pastel:, out:, previous: false, year: nil)
            TopScorers.run(pastel:, out:, previous:, year: coerce_cli_year(year))
          end

          # --- Menu · active league only -------------------------------------------

          def from_menu_standings_active(pastel:, out:)
            LeagueStandings.run(pastel:, out:)
          end

          def from_menu_fixtures_active(pastel:, out:)
            SeasonFixtures.run(pastel:, out:)
          end

          def from_menu_scorers_active(pastel:, out:)
            TopScorers.run(pastel:, out:)
          end

          # --- Menu · archived season picker → explicit league ----------------------

          def from_menu_standings_archive(pastel:, out:, prompt:)
            lg = pick_completed_league(pastel:, prompt:, title: "Which archived season?")
            return unless lg

            LeagueStandings.run(pastel:, out:, league: lg)
          end

          def from_menu_fixtures_archive(pastel:, out:, prompt:)
            lg = pick_completed_league(pastel:, prompt:, title: "Fixtures for which season?")
            return unless lg

            SeasonFixtures.run(pastel:, out:, league: lg)
          end

          private

          def coerce_cli_year(year)
            return nil if year.nil?

            Integer(year)
          end

          def pick_completed_league(pastel:, prompt:, title:)
            rows = Repositories::LeagueRepository.completed_ordered
            return nil if rows.empty?

            choices = rows.map { |lg| { name: "#{lg.year} · #{lg.name}", value: lg } }
            prompt.select(pastel.bold(title), choices, filter: true)
          end
        end
      end
    end
  end
end
