# frozen_string_literal: true

require_relative "../domain/goal_event"
require_relative "base"

module Gaffer
  module Repositories
    class GoalEventRepository < Base
      class << self
        # @param events [Array<Domain::GoalEvent>] id may be nil
        def save_batch(events)
          return if events.nil? || events.empty?

          rows = events.map do |e|
            {
              fixture_id: e.fixture_id.to_i,
              player_id: e.player_id.to_i,
              club_id: e.club_id.to_i,
              side: e.side.to_s
            }
          end
          db[:goal_events].multi_insert(rows)
          nil
        end

        # @return [Array<Domain::GoalEvent>]
        def for_season(league_id)
          sid = league_id.to_i
          db.fetch(<<~SQL, sid).all.map { |r| goal_event_row(r) }
            SELECT goal_events.*
            FROM goal_events
            INNER JOIN fixtures ON fixtures.id = goal_events.fixture_id
            WHERE fixtures.season_id = ?
            ORDER BY goal_events.fixture_id ASC, goal_events.side ASC, goal_events.id ASC
          SQL
        end

        # @return [Array<{ player_id: Integer, goals: Integer }>] descending by goals, then player_id
        def totals_by_player(league_id)
          sid = league_id.to_i
          db.fetch(<<~SQL, sid).all.map { |r| { player_id: r[:player_id].to_i, goals: r[:goals].to_i } }
            SELECT goal_events.player_id AS player_id, COUNT(*) AS goals
            FROM goal_events
            INNER JOIN fixtures ON fixtures.id = goal_events.fixture_id
            WHERE fixtures.season_id = ?
            GROUP BY goal_events.player_id
            ORDER BY goals DESC, player_id ASC
          SQL
        end

        # @return [Array<Domain::GoalEvent>]
        def for_fixture(fixture_id)
          fid = fixture_id.to_i
          db[:goal_events].where(fixture_id: fid).order(:side, :id).map do |row|
            goal_event_row(row)
          end
        end

        private

        def goal_event_row(row)
          Domain::GoalEvent.new(
            id: row[:id],
            fixture_id: row[:fixture_id],
            player_id: row[:player_id],
            club_id: row[:club_id],
            side: row[:side].to_s
          )
        end
      end
    end
  end
end
