# frozen_string_literal: true

require_relative "fixture"

module Gaffer
  module Domain
    # Pure round-robin scheduler: home-and-away double round-robin, no DB access.
    #
    # Algorithm: circle method — one club fixed, the other (n-1) rotate each round;
    # pair first with last, second with second-last, etc. First pass is (n-1) gameweeks,
    # then the same slot order with home/away flipped for the return leg.
    #
    # @see CLAUDE.md — Phase 1b Step 3
    class FixtureGenerator
      class << self
        # @param club_ids [Array<Integer,#to_i>] distinct club ids, count must be even and >= 4
        # @param league_id [Integer,#to_i] stored on each fixture as {#season_id} (DB column alias)
        # @return [Array<Fixture>] id: nil, played: false, gameweek 1..(2*(n-1))
        def generate(club_ids:, league_id:)
          ids = club_ids.map(&:to_i)
          raise ArgumentError, "need at least two clubs" if ids.size < 2
          raise ArgumentError, "club_ids must be distinct" if ids.uniq.size != ids.size
          raise ArgumentError, "need an even number of clubs" unless ids.size.even?

          lid = league_id.to_i

          rounds = round_pairings(ids)
          fixtures = []
          gameweek = 0

          rounds.each do |pairs|
            gameweek += 1
            pairs.each do |home_id, away_id|
              fixtures << build_fixture(lid, gameweek, home_id, away_id)
            end
          end

          rounds.each do |pairs|
            gameweek += 1
            pairs.each do |home_id, away_id|
              fixtures << build_fixture(lid, gameweek, away_id, home_id)
            end
          end

          fixtures
        end

        private

        def build_fixture(league_id, gameweek, home_club_id, away_club_id)
          Fixture.new(
            id: nil,
            season_id: league_id,
            gameweek: gameweek,
            home_club_id: home_club_id,
            away_club_id: away_club_id,
            played: false
          )
        end

        # @return [Array<Array<Array(Integer,Integer)>>>] length (n-1); each element is n/2 pairs [home, away]
        def round_pairings(team_ids)
          n = team_ids.size
          fixed = team_ids[0]
          rest = team_ids[1..]

          (0...(n - 1)).map do |r|
            ordered = [fixed] + rest.rotate(r)
            (0...(n / 2)).map do |i|
              [ordered[i], ordered[n - 1 - i]]
            end
          end
        end
      end
    end
  end
end
