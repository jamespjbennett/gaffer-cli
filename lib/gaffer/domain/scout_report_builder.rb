# frozen_string_literal: true

require_relative "club"
require_relative "scout_report"
require_relative "lineup"
require_relative "league_table"
require_relative "match_engine"
require_relative "../repositories/fixture_repository"
require_relative "../repositories/club_repository"
require_relative "../repositories/player_repository"
require_relative "../repositories/goal_event_repository"

module Gaffer
  module Domain
    # Pure aggregator for [`ScoutReport`]; repos are only read-path entry points here.
    module ScoutReportBuilder
      class << self
        # @param opponent_club [Domain::Club]
        # @param managed_club [Domain::Club]
        # @param league_id [Integer] season row id (`fixtures.season_id`)
        # @param gameweek [Integer]
        # @param hosting_managed [Boolean] true if the player's club hosts this fixture
        # @param engine [#attack_defense_rating_for_xi] defaults to Domain::MatchEngine
        # @return [ScoutReport]
        def build(opponent_club:, league_id:, managed_club:, gameweek:, hosting_managed:, engine: nil)
          raise ArgumentError, "opponent_club required" unless opponent_club
          raise ArgumentError, "managed_club required" unless managed_club

          oid = opponent_club.id.to_i
          mid = managed_club.id.to_i
          raise ArgumentError, "club id blank" unless oid.positive? && mid.positive?

          lid = league_id.to_i
          raise ArgumentError, "league_id blank" unless lid.positive?

          eng = engine || Domain::MatchEngine.new
          gw = Integer(gameweek)

          club_ids = Repositories::FixtureRepository.club_ids_for_season(lid)
          clubs = Repositories::ClubRepository.for_ids_ordered(club_ids)
          results = Repositories::FixtureRepository.settled_scores_for_season(lid)

          rows = Domain::LeagueTable.standings_for(clubs: clubs, results: results)
          positions = Domain::LeagueTable.positions_by_club(rows)

          opp_row = rows.find { |r| r.club.id.to_i == oid }
          mgr_row = rows.find { |r| r.club.id.to_i == mid }

          played = opp_row&.played.to_i
          league_size = clubs.size.positive? ? clubs.size : 1
          pos = positions[oid] || league_size

          mgr_played = mgr_row&.played.to_i
          mgr_pts = mgr_row&.points.to_i
          mgr_pos = positions[mid] || league_size

          opp_pts = opp_row&.points.to_i

          form = recent_form_for(opponent_club_id: oid, chronological_results: results)

          opp_players = Repositories::PlayerRepository.for_club(oid)
          xi = Domain::Lineup.pick_best_xi(opp_players)
          atk_def =
            if xi.size == 11
              eng.attack_defense_rating_for_xi(club: opponent_club, players: xi)
            else
              [1e-9, 1e-9].map(&:to_f)
            end

          our_players = Repositories::PlayerRepository.for_club(mid)
          our_xi = Domain::Lineup.pick_best_xi(our_players)
          ours =
            if our_xi.size == 11
              eng.attack_defense_rating_for_xi(club: managed_club, players: our_xi)
            else
              [1e-9, 1e-9].map(&:to_f)
            end

          top = top_scorer_for_club(league_id: lid, opponent_club_id: oid)
          watch = pick_watch_focus(top_scorer: top, opp_players: opp_players)

          ScoutReport.new(
            opponent: opponent_club,
            managed_club: managed_club,
            gameweek: gw,
            hosting_managed: !!hosting_managed,
            league_position: pos,
            league_size: league_size,
            played: played,
            manager_league_position: mgr_pos,
            manager_played: mgr_played,
            manager_points: mgr_pts,
            opponent_points: opp_pts,
            recent_form: form,
            attack_rating: atk_def[0],
            defence_rating: atk_def[1],
            our_attack_rating: ours[0],
            our_defence_rating: ours[1],
            top_scorer: top,
            watch_focus: watch
          )
        end

        # @param chronological_results [Array<Hash>] as from FixtureRepository.settled_scores_for_season
        # @return [Array<Symbol>] last five :w, :d, :l from opponent POV (oldest first among those five)
        def recent_form_for(opponent_club_id:, chronological_results:)
          oid = opponent_club_id.to_i
          list = []

          chronological_results.each do |r|
            hid = Integer(r[:home_club_id] || r["home_club_id"])
            aid = Integer(r[:away_club_id] || r["away_club_id"])
            hs = (r[:home_score] || r["home_score"]).to_i
            aw = (r[:away_score] || r["away_score"]).to_i

            outcome =
              if hid == oid
                if hs > aw
                  :w
                elsif hs < aw
                  :l
                else
                  :d
                end
              elsif aid == oid
                if aw > hs
                  :w
                elsif aw < hs
                  :l
                else
                  :d
                end
              else
                next
              end

            list << outcome
          end

          list.last(5)
        end

        private

        def top_scorer_for_club(league_id:, opponent_club_id:)
          totals = Repositories::GoalEventRepository.totals_by_player(league_id)
          cid = opponent_club_id.to_i

          totals.each do |row|
            pl = Repositories::PlayerRepository.find(row[:player_id])
            next unless pl
            next unless pl.club_id.to_i == cid

            return { player: pl, goals: row[:goals].to_i }
          end

          nil
        end

        def pick_watch_focus(top_scorer:, opp_players:)
          if top_scorer && top_scorer[:goals].to_i.positive?
            return {
              player: top_scorer[:player],
              kind: :scorer,
              goals: top_scorer[:goals].to_i
            }
          end

          list = opp_players.reject { |pl| pl.position&.to_sym == :gk }
          return nil if list.empty?

          att_mid =
            list.select { |pl| %i[att mid].include?(pl.position&.to_sym) }
          fwd_pool = att_mid.empty? ? list : att_mid

          live =
            fwd_pool.max_by do |pl|
              iv(pl, :shooting) + iv(pl, :pace) + iv(pl, :dribbling)
            end

          return { player: live, kind: :livewire, goals: nil } if live

          defs = list.select { |pl| pl.position&.to_sym == :def }
          rock = defs.max_by { |pl| iv(pl, :defending) || 0 }
          return { player: rock, kind: :enforcer, goals: nil } if rock

          { player: list.first, kind: :livewire, goals: nil }
        end

        def iv(player, attr)
          v = player.public_send(attr)
          v.nil? ? 62 : v.to_i.clamp(1, 99)
        end
      end
    end
  end
end
