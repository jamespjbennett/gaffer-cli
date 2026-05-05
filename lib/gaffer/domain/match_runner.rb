# frozen_string_literal: true

require_relative "match_engine"
require_relative "match_event"
require_relative "match_lineup_moment"
require_relative "match_result"
require_relative "match_snapshot"
require_relative "scorer_picker"

module Gaffer
  module Domain
    # Minute-by-minute progressive sim — interactive league fixtures.
    class MatchRunner
      DRIFT = (0.33 / 45.0).freeze
      EXTRA_MISS = 0.055

      attr_reader :home_club, :away_club, :home_players, :away_players,
        :home_tactic, :away_tactic, :minute, :events,
        :opening_home_players, :opening_away_players,
        :home_score, :away_score

      # @param seed [Integer]
      def initialize(home_club:, away_club:, home_players:, away_players:,
                     home_tactic:, away_tactic:, seed:, engine: nil)
        @seed = seed.to_i
        @rng = Random.new(@seed)
        @goal_pick = Random.new(@seed ^ 41_983)
        @engine = engine || Domain::MatchEngine.new
        @home_club = home_club
        @away_club = away_club
        @home_players = Array(home_players).dup
        @away_players = Array(away_players).dup
        @opening_home_players = @home_players.dup
        @opening_away_players = @away_players.dup
        @home_tactic = home_tactic
        @away_tactic = away_tactic
        @home_fatigue = floats(@home_players.size)
        @away_fatigue = floats(@away_players.size)
        lh, la, hk_at, hk_df, ak_at, ak_df = lambdas_between(
          @opening_home_players, @opening_away_players, floats(@opening_home_players.size),
          floats(@opening_away_players.size)
        )
        stash_kick_ratings!(hk_at, hk_df, ak_at, ak_df)
        @lam_h_track = lh
        @lam_a_track = la
        @minute = 0
        @home_score = @away_score = 0
        @events = []
      end

      def play_to_minute(target)
        cap = Integer(target).clamp(0, 90)
        step while @minute < cap
        snapshot
      end

      # Full-lineup refresh entering second half — fatigue remap by player id for returning subs.
      def apply_second_half!(home_xi:, away_xi:, home_tactic:, away_tactic:)
        rebound(:home, home_xi, home_tactic)
        rebound(:away, away_xi, away_tactic)
      end

      def snapshot
        Domain::MatchSnapshot.new(
          minute: @minute,
          home_score: @home_score,
          away_score: @away_score,
          home_fatigue: @home_fatigue.dup,
          away_fatigue: @away_fatigue.dup,
          events: @events.dup,
          team_stats: sheet
        )
      end

      def finalize_match_result
        play_to_minute(90) if @minute < 90
        Domain::MatchResult.new(
          home_score: @home_score,
          away_score: @away_score,
          home_xg_lambda: @lam_h_track.to_f,
          away_xg_lambda: @lam_a_track.to_f,
          home_attack_rating: @kick_h_at.to_f,
          home_defense_rating: @kick_h_df.to_f,
          away_attack_rating: @kick_a_at.to_f,
          away_defense_rating: @kick_a_df.to_f,
          home_scorers: scorer_stack(:home),
          away_scorers: scorer_stack(:away)
        )
      end

      private

      def scorer_stack(axis)
        @events.select { |e| axis == e.side && e.type == :goal }.filter_map(&:player)
      end

      def stash_kick_ratings!(hk_at, hk_df, ak_at, ak_df)
        @kick_h_at = hk_at
        @kick_h_df = hk_df
        @kick_a_at = ak_at
        @kick_a_df = ak_df
      end

      def rebound(which, xi, tac)
        if which == :home
          carry_fat!(:home, xi)
          @home_players = xi.dup
          @home_tactic = tac
        else
          carry_fat!(:away, xi)
          @away_players = xi.dup
          @away_tactic = tac
        end
      end

      def carry_fat!(axis, xi)
        table = memo_fat(axis)
        fat = floats(xi.size)
        xi.each_with_index { |pl, i| fat[i] = table.fetch(pl.id.to_i, 0.0) }
        write_fat(axis, fat)
      end

      def write_fat(axis, arr)
        axis == :home ? (@home_fatigue = arr) : (@away_fatigue = arr)
      end

      def memo_fat(which)
        id_list, fat = pairing(which)
        id_list.each_with_index.each_with_object({}) do |(pid, ix), memo|
          next unless pid&.to_i&.nonzero?

          memo[pid.to_i] = fat[ix].to_f
        end
      end

      def pairing(which)
        which == :home ? [@home_players.map(&:id), @home_fatigue] : [@away_players.map(&:id), @away_fatigue]
      end

      def floats(n)
        Array.new(Integer(n)) { 0.0 }
      end

      def step
        @minute += 1
        push_fat!
        pulse!
      end

      def push_fat!
        tilt!(@home_fatigue)
        tilt!(@away_fatigue)
      end

      def tilt!(arr)
        arr.map! { |f| (f + DRIFT).clamp(0.0, 1.0) }
      end

      def pulse!
        lh, la, *_ = refresh_lambdas
        @lam_h_track = lh
        @lam_a_track = la
        ph = prob(lh)
        pa = prob(la)
        gh = @rng.rand < ph
        ga = @rng.rand < pa
        fire_goal!(:home) if gh
        fire_goal!(:away) if ga
        squander(ph, pa) unless gh || ga
      end

      def prob(lam)
        (lam.to_f / 90.0).clamp(0.0, 0.42)
      end

      def squander(ph, pa)
        return unless @rng.rand < EXTRA_MISS

        squander_side(side_weight(ph, pa))
      end

      def side_weight(ph, pa)
        t = ph + pa + Tiny::EPS
        @rng.rand < (ph / t) ? :home : :away
      end

      module Tiny
        EPS = 1e-9
      end

      def squander_side(side)
        ply = snag(xi_for(side))
        desc = +"Big chance missed (#{@minute}'): #{name_of(ply)}"
        emit(side, ply, :big_chance, desc)
      end

      def fire_goal!(side)
        bump(side)
        ply = snag(xi_for(side))
        tag = side == :home ? "HOME" : "AWAY"
        desc = +"GOAL [#{tag}] #{name_of(ply)} · #{@minute}'"
        emit(side, ply, :goal, desc)
      end

      def emit(side, ply, kind, desc)
        @events << Domain::MatchEvent.new(
          minute: @minute,
          side: side,
          type: kind,
          player: ply,
          description: desc
        )
      end

      def bump(side)
        if side == :home
          @home_score += 1
        else
          @away_score += 1
        end
      end

      def xi_for(side)
        side == :home ? @home_players : @away_players
      end

      def snag(xi)
        Domain::ScorerPicker.pick(xi, 1, @goal_pick).first ||
          xi.find { |pl| pl&.position&.to_sym != :gk } ||
          xi.first
      end

      def name_of(ply)
        n = ply&.name.to_s.strip
        n.empty? ? "?" : n
      end

      def refresh_lambdas
        @engine.minute_lambdas(
          home: moment(@home_club, @home_players, @home_fatigue, @home_tactic),
          away: moment(@away_club, @away_players, @away_fatigue, @away_tactic),
          rng: @rng
        )
      end

      def moment(club, squad, fat, tac)
        Domain::MatchLineupMoment.new(club:, players: squad, fatigue: fat, tactic: tac)
      end

      def lambdas_between(hp, ap, hf, af)
        @engine.minute_lambdas(
          home: moment(@home_club, hp, hf, @home_tactic),
          away: moment(@away_club, ap, af, @away_tactic),
          rng: @rng
        )
      end

      def sheet
        { home: pack(:home), away: pack(:away) }
      end

      def pack(side)
        evs = @events.select { |e| e.side == side }
        g = evs.count { |e| e.type == :goal }
        bc = evs.count { |e| e.type == :big_chance }
        {
          possession: poss_share(side),
          shots: g + bc,
          big_chances: bc,
          goals: g
        }
      end

      def poss_share(side)
        h = (@lam_h_track || 1.4).to_f
        a = (@lam_a_track || 1.4).to_f
        pct = (h / (h + a + Tiny::EPS)) * 100.0
        side == :home ? pct.round(1) : (100.0 - pct).round(1)
      end
    end
  end
end
