# frozen_string_literal: true

require "json"

module Gaffer
  module Repositories
    class MatchRepository < Base
      class << self
        def find(id)
          row = matches_ds.where(id:).first
          row ? row_to_domain(row) : nil
        end

        def for_fixture(fixture_id)
          row = matches_ds.where(fixture_id:).first
          row ? row_to_domain(row) : nil
        end

        def save(match)
          attrs = domain_to_attrs(match)
          if match.id
            matches_ds.where(id: match.id).update(attrs)
            row_to_domain(matches_ds.where(id: match.id).first)
          else
            new_id = matches_ds.insert(attrs)
            row_to_domain(matches_ds.where(id: new_id).first)
          end
        end

        # @param fixture_ids [Array<Integer>]
        # @return [Hash{Integer => Domain::Match}]
        def indexed_by_fixture_id(fixture_ids)
          ids = Array(fixture_ids).map(&:to_i).uniq
          return {} if ids.empty?

          matches_ds.where(fixture_id: ids).each_with_object({}) do |row, acc|
            acc[row[:fixture_id]] = row_to_domain(row)
          end
        end

        private

        def matches_ds
          db[:matches]
        end

        def row_to_domain(row)
          Domain::Match.new(
            id: row[:id],
            fixture_id: row[:fixture_id],
            home_score: row[:home_score],
            away_score: row[:away_score],
            home_possession: row[:home_possession],
            home_shots: row[:home_shots],
            home_shots_ot: row[:home_shots_ot],
            away_shots: row[:away_shots],
            away_shots_ot: row[:away_shots_ot],
            events: decode_json_array(row[:events]),
            player_ratings: decode_json_ratings(row[:player_ratings]),
            narrative: row[:narrative]
          )
        end

        def domain_to_attrs(match)
          {
            fixture_id: match.fixture_id,
            home_score: match.home_score.nil? ? 0 : match.home_score,
            away_score: match.away_score.nil? ? 0 : match.away_score,
            home_possession: match.home_possession,
            home_shots: match.home_shots,
            home_shots_ot: match.home_shots_ot,
            away_shots: match.away_shots,
            away_shots_ot: match.away_shots_ot,
            events: JSON.generate(match.events.is_a?(Array) ? match.events : []),
            player_ratings: JSON.generate(ratings_for_json(match.player_ratings)),
            narrative: match.narrative
          }
        end

        def ratings_for_json(player_ratings)
          return {} unless player_ratings.is_a?(Hash)

          player_ratings.transform_keys(&:to_s)
        end

        def decode_json_array(text)
          return [] if text.nil? || text.to_s.strip.empty?

          parsed = JSON.parse(text.to_s)
          Array(parsed)
        rescue JSON::ParserError
          []
        end

        def decode_json_ratings(text)
          return {} if text.nil? || text.to_s.strip.empty?

          parsed = JSON.parse(text.to_s)
          return {} unless parsed.is_a?(Hash)

          parsed.each_with_object({}) do |(k, v), acc|
            key = Integer(k.to_s)
            val = coerce_rating(v)
            acc[key] = val
          end
        rescue JSON::ParserError, ArgumentError
          {}
        end

        def coerce_rating(raw)
          f = Float(raw.to_s)
          return nil unless f.finite?

          (f == f.to_i ? f.to_i : f.round(1))
        rescue ArgumentError, TypeError
          nil
        end
      end
    end
  end
end
