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

        # Bulk insert for generated schedules (same shape as `domain_to_attrs`).
        def import_new_fixtures!(fixtures)
          return 0 if fixtures.empty?

          rows = fixtures.map { domain_to_attrs(_1) }
          fixtures_ds.multi_insert(rows)
          rows.size
        end

        def next_for_club(season_id:, club_id:)
          sid = season_id.to_i
          cid = club_id.to_i
          row = fixtures_ds
            .where(season_id: sid, played: false)
            .where(Sequel.|({ home_club_id: cid }, { away_club_id: cid }))
            .order(:gameweek, :id).first

          row ? row_to_domain(row) : nil
        end

        def for_season_and_gameweek(season_id:, gameweek:)
          fixtures_ds
            .where(season_id: season_id.to_i, gameweek: gameweek.to_i)
            .order(:id)
            .map { row_to_domain(_1) }
        end

        def max_gameweek(season_id)
          fixtures_ds.where(season_id: season_id.to_i).max(:gameweek)&.to_i
        end

        def unplayed_count(season_id)
          fixtures_ds.where(season_id: season_id.to_i, played: false).count
        end

        def settled_scores_for_season(season_id)
          sid = season_id.to_i
          fx_rows = fixtures_ds.where(season_id: sid, played: true).order(:gameweek, :id)
            .select(:id, :home_club_id, :away_club_id).all
          ids = fx_rows.map { _1[:id] }
          return [] if ids.empty?

          matches_by_fx = {}
          db[:matches].where(fixture_id: ids).each { |row| matches_by_fx[row[:fixture_id]] = row }

          fx_rows.filter_map do |f|
            m = matches_by_fx[f[:id]]
            next nil unless m

            {
              home_club_id: f[:home_club_id],
              away_club_id: f[:away_club_id],
              home_score: m[:home_score],
              away_score: m[:away_score]
            }
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
