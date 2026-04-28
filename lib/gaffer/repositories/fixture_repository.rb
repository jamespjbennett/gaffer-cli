# frozen_string_literal: true

module Gaffer
  module Repositories
    class FixtureRepository < Base
      class << self
        def find(id)
          row = fixtures_ds.where(id:).first
          row ? row_to_domain(row) : nil
        end

        def for_season(season_id)
          fixtures_ds.where(season_id:).order(:gameweek).map { row_to_domain(_1) }
        end

        def save(fixture)
          attrs = domain_to_attrs(fixture)
          if fixture.id
            fixtures_ds.where(id: fixture.id).update(attrs)
            row_to_domain(fixtures_ds.where(id: fixture.id).first)
          else
            new_id = fixtures_ds.insert(attrs)
            row_to_domain(fixtures_ds.where(id: new_id).first)
          end
        end

        private

        def fixtures_ds
          db[:fixtures]
        end

        def row_to_domain(row)
          Domain::Fixture.new(
            id: row[:id],
            season_id: row[:season_id],
            gameweek: row[:gameweek],
            home_club_id: row[:home_club_id],
            away_club_id: row[:away_club_id],
            played: row[:played]
          )
        end

        def domain_to_attrs(fixture)
          {
            season_id: fixture.season_id,
            gameweek: fixture.gameweek,
            home_club_id: fixture.home_club_id,
            away_club_id: fixture.away_club_id,
            played: fixture.played
          }
        end
      end
    end
  end
end
