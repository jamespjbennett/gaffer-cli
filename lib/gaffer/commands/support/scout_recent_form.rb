# frozen_string_literal: true

module Gaffer
  module Commands
    module Support
      # Last-five W/D/L strip from settled results — opponent’s point of view.
      module ScoutRecentForm
        class << self
          # @param chronological_results [Array<Hash>] as from FixtureRepository#settled_scores_for_season
          # @return [Array<Symbol>] last five :w, :d, :l (oldest first among those five)
          def last_five(opponent_club_id:, chronological_results:)
            oid = opponent_club_id.to_i
            list = chronological_results.filter_map { |r| outcome_for_row(r, oid) }
            list.last(5)
          end

          private

          def outcome_for_row(r, oid)
            hid = int_key(r, :home_club_id)
            aid = int_key(r, :away_club_id)
            hs = score_key(r, :home_score)
            aw = score_key(r, :away_score)

            outcome_as_home_team(oid:, hid:, hs:, aw:) ||
              outcome_as_away_team(oid:, aid:, hs:, aw:)
          end

          def outcome_as_home_team(oid:, hid:, hs:, aw:)
            resolve_table_outcome(side_id: oid, venue_home_id: hid, side_goals: hs, oppo_goals: aw)
          end

          def outcome_as_away_team(oid:, aid:, hs:, aw:)
            resolve_table_outcome(side_id: oid, venue_home_id: aid, side_goals: aw, oppo_goals: hs)
          end

          def resolve_table_outcome(side_id:, venue_home_id:, side_goals:, oppo_goals:)
            return nil unless venue_home_id == side_id

            wdl(side_goals, oppo_goals)
          end

          def wdl(forward, against)
            return :w if forward > against
            return :l if forward < against

            :d
          end

          def int_key(r, key)
            Integer(r[key] || r[key.to_s])
          end

          def score_key(r, key)
            (r[key] || r[key.to_s]).to_i
          end
        end
      end
    end
  end
end
