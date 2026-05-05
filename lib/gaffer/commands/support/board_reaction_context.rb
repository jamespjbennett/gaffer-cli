# frozen_string_literal: true

require_relative "../../domain/league_table"
require_relative "../../narratives/board_reaction"
require_relative "../../repositories/club_repository"
require_relative "../../repositories/fixture_repository"

module Gaffer
  module Commands
    module Support
      # Builds [`Narratives::BoardReaction::Context`] from persisted GW standings.
      module BoardReactionContext
        extend self

        # @return [Narratives::BoardReaction::Context, nil]
        def build(state:, summaries:, managed_club_id:)
          mine = yours(summaries, managed_club_id)
          return unless mine

          rows = standings(state.league.id)
          pos = Domain::LeagueTable.positions_by_club(rows)
          oid = counterpart_id(mine.fixture, managed_club_id)
          Narratives::BoardReaction::Context.new(
            managed_club: state.managed_club,
            opponent_club: state.clubs_by_id.fetch(oid),
            home_score: mine.result.home_score,
            away_score: mine.result.away_score,
            hosting_managed: mine.fixture.home_club_id.to_i == managed_club_id.to_i,
            managed_rank: pos.fetch(managed_club_id.to_i),
            opponent_rank: pos.fetch(oid),
            league_size: rows.size
          )
        end

        private

        def yours(summaries, mid)
          summaries.find { |s| fx_ids(s).include?(mid.to_i) }
        end

        def fx_ids(s)
          [s.fixture.home_club_id, s.fixture.away_club_id].map(&:to_i)
        end

        def standings(league_id)
          clubs = Repositories::ClubRepository.for_league(league_id)
          got = Repositories::FixtureRepository.settled_scores_for_season(league_id)
          Domain::LeagueTable.standings_for(clubs:, results: got)
        end

        def counterpart_id(fixture, mid)
          home = fixture.home_club_id.to_i
          home == mid.to_i ? fixture.away_club_id.to_i : home
        end
      end
    end
  end
end
