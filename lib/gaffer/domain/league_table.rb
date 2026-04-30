# frozen_string_literal: true

require_relative "table_row"

module Gaffer
  module Domain
    # Computes sorted standings from a club roster and finished scores (pure).
    #
    # @see CLAUDE.md Phase 1b Steps 5–6
    module LeagueTable
      module_function

      # @param clubs [Array<Club>] clubs in this league roster
      # @param results [Array<Hash,#[] >>] settled matches: home_club_id, away_club_id, home_score, away_score
      # @return [Array<TableRow>] sorted by points, GD, GF (desc), club name asc
      def standings_for(clubs:, results:)
        raise ArgumentError, "clubs blank" if clubs.nil? || clubs.empty?

        tallies =
          clubs.each_with_object({}) do |club, memo|
            memo[club.id] = {
              played: 0,
              won: 0,
              drawn: 0,
              lost: 0,
              gf: 0,
              ga: 0,
              points: 0
            }
          end

        results.each do |r|
          hid = coerce_id(r[:home_club_id] || r["home_club_id"])
          aid = coerce_id(r[:away_club_id] || r["away_club_id"])
          hs = coerce_int(r[:home_score] || r["home_score"])
          asym = coerce_int(r[:away_score] || r["away_score"])

          ht = tallies[hid]
          at = tallies[aid]

          ht[:played] += 1
          at[:played] += 1
          ht[:gf] += hs
          ht[:ga] += asym
          at[:gf] += asym
          at[:ga] += hs

          if hs > asym
            ht[:won] += 1
            ht[:points] += 3
            at[:lost] += 1
          elsif hs < asym
            at[:won] += 1
            at[:points] += 3
            ht[:lost] += 1
          else
            ht[:drawn] += 1
            at[:drawn] += 1
            ht[:points] += 1
            at[:points] += 1
          end
        end

        clubs
          .map do |club|
            t = tallies.fetch(club.id)
            TableRow.new(
              club: club,
              played: t[:played],
              won: t[:won],
              drawn: t[:drawn],
              lost: t[:lost],
              gf: t[:gf],
              ga: t[:ga],
              points: t[:points]
            )
          end
          .sort_by { |row| [-row.points, -(row.gf - row.ga), -row.gf, row.club.name.to_s] }
      end

      # @param rows [Array<TableRow>]
      # @return [Hash{ Integer => Integer }] club_id => league position (1-based)
      def positions_by_club(rows)
        rows.each_with_index.with_object({}) do |(row, idx), memo|
          memo[row.club.id.to_i] = idx + 1
        end
      end

      def coerce_id(raw)
        Integer(raw.to_s)
      rescue ArgumentError, TypeError
        raise ArgumentError, "bad club id in result row: #{raw.inspect}"
      end

      def coerce_int(raw)
        Integer(raw.to_s)
      rescue ArgumentError, TypeError
        0
      end
    end
  end
end
