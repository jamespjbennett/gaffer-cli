# frozen_string_literal: true

require_relative "club"
require_relative "player"
require_relative "match_result"
require_relative "morale_form_multiplier"
require_relative "scorer_picker"

module Gaffer
  module Domain
    # Pure, deterministic simulator: squad composition + tactics + RNG seed → Poisson goals.
    # See CLAUDE.md — no persistence, no CLI.
    class MatchEngine
      # Tweaked so ends feel noticeably different in sims (still symmetric around :balanced).
      TACTIC_MODIFIERS = {
        all_out_attack: { attack_multiplier: 1.28, defense_multiplier: 0.72 },
        attacking:        { attack_multiplier: 1.12, defense_multiplier: 0.88 },
        balanced:         { attack_multiplier: 1.0,  defense_multiplier: 1.0 },
        defensive:        { attack_multiplier: 0.88, defense_multiplier: 1.12 },
        park_the_bus:     { attack_multiplier: 0.72, defense_multiplier: 1.28 }
      }.freeze

      DEF_EPS = 1e-9

      def initialize(xg_scale: 3.5, home_boost: 0.05, xg_variance: 0.08)
        @xg_scale = xg_scale
        @home_boost = home_boost
        @xg_variance = xg_variance
      end

      # @param seed [Integer, nil] Omit for a new Random each call (scores vary). Pass an Integer to fix the
      #                             outcome — same squads+tactics + same seed → same score every time (tests/debug).
      # @return [MatchResult]
      def simulate(
        home_club:, home_players:, away_club:, away_players:,
        home_tactic: :balanced, away_tactic: :balanced,
        seed: nil
      )
        raise ArgumentError, "home_players empty" if home_players.nil? || home_players.empty?
        raise ArgumentError, "away_players empty" if away_players.nil? || away_players.empty?

        rng =
          if seed.nil?
            Random.new
          else
            Random.new(seed)
          end

        home_attack_raw  = squad_mean(home_players, :attack)
        home_defense_raw = squad_mean(home_players, :defense)
        away_attack_raw  = squad_mean(away_players, :attack)
        away_defense_raw = squad_mean(away_players, :defense)

        home_attack  = apply_club_quality(home_attack_raw, home_club.reputation) * tactic_mult(home_tactic, :attack)
        home_defense = apply_club_quality(home_defense_raw, home_club.reputation) * tactic_mult(home_tactic, :defense)
        away_attack  = apply_club_quality(away_attack_raw, away_club.reputation) * tactic_mult(away_tactic, :attack)
        away_defense = apply_club_quality(away_defense_raw, away_club.reputation) * tactic_mult(away_tactic, :defense)

        lam_home = lambda_goals_from_strength(home_attack, away_defense, home_advantage: true, rng:)
        lam_away = lambda_goals_from_strength(away_attack, home_defense, home_advantage: false, rng:)

        home_goals = sample_poisson_goals(lam_home, rng)
        away_goals = sample_poisson_goals(lam_away, rng)

        MatchResult.new(
          home_score: home_goals,
          away_score: away_goals,
          home_xg_lambda: lam_home,
          away_xg_lambda: lam_away,
          home_attack_rating: home_attack,
          home_defense_rating: home_defense,
          away_attack_rating: away_attack,
          away_defense_rating: away_defense,
          home_scorers: Domain::ScorerPicker.pick(home_players, home_goals, rng),
          away_scorers: Domain::ScorerPicker.pick(away_players, away_goals, rng)
        )
      end

      # Effective attack/defence ratings for an XI exactly as `:balanced` would apply (no RNG) — scouting / UI only.
      # @return [Array(Float, Float)] attack, defence
      def attack_defense_rating_for_xi(club:, players:)
        atk = apply_club_quality(squad_mean(players, :attack), club.reputation)
        defw = apply_club_quality(squad_mean(players, :defense), club.reputation)
        [atk, defw]
      end

      private

      def tactic_mult(tactic, axis)
        m = TACTIC_MODIFIERS.fetch(tactic) { raise ArgumentError, "unknown tactic #{tactic.inspect}" }
        m.fetch(axis == :attack ? :attack_multiplier : :defense_multiplier)
      end

      def apply_club_quality(raw_rating, reputation)
        rep = reputation.to_i.clamp(1, 100)
        factor = 1.0 + ((rep - 50) / 110.0) # ±~0.45 at extremes vs rep 50
        raw_rating * factor
      end

      def squad_mean(players, mode)
        scores = players.map { |pl| contribution(pl, mode) }
        return DEF_EPS if scores.empty?

        scores.sum.to_f / scores.size
      end

      def contribution(pl, mode)
        case mode
        when :attack then contribution_attack(pl)
        when :defense then contribution_defense(pl)
        else raise ArgumentError, mode.to_s
        end
      end

      def contribution_attack(p)
        base = raw_contribution_attack(p)
        apply_morale_form(base, p)
      end

      def raw_contribution_attack(p)
        pace = iv(p, :pace)
        sho = iv(p, :shooting)
        pas = iv(p, :passing)
        drib = iv(p, :dribbling)

        core = ((pace + sho + pas + drib) / 4.0)

        pos = p.position&.to_sym
        case pos
        when :gk then iv(p, :goalkeeping) * 0.14 + pas * 0.16 + iv(p, :physical) * 0.12
        when :def then core * 0.85
        when :mid then core * 0.92
        when :att then core * 1.06
        else core * 0.9
        end
      end

      def contribution_defense(p)
        base = raw_contribution_defense(p)
        apply_morale_form(base, p)
      end

      def raw_contribution_defense(p)
        pace = iv(p, :pace)
        defn = iv(p, :defending)
        phys = iv(p, :physical)
        gkk = iv(p, :goalkeeping)

        case p.position&.to_sym
        when :gk then (gkk * 0.62 + defn * 0.21 + phys * 0.17)
        when :def then (defn * 0.55 + pace * 0.17 + phys * 0.28)
        when :mid then (defn * 0.40 + pace * 0.20 + phys * 0.40)
        when :att then (defn * 0.50 + pace * 0.25 + phys * 0.25)
        else (defn * 0.42 + pace * 0.22 + phys * 0.36)
        end
      end

      def apply_morale_form(raw, player)
        raw * Domain::MoraleFormMultiplier.for(player)
      end

      def iv(p, attr)
        v = p.public_send(attr)
        v.nil? ? 62 : v.to_i.clamp(1, 99)
      end

      def lambda_goals_from_strength(team_attack, opponent_defense, home_advantage:, rng:)
        attack = [team_attack, DEF_EPS].max
        defense = [opponent_defense, DEF_EPS].max
        share = attack / (attack + defense)
        share += @home_boost if home_advantage
        share += rng.rand(-@xg_variance..@xg_variance)
        share = share.clamp(0.005, 0.965)
        (share * @xg_scale).round(6)
      end

      def sample_poisson_goals(lambda_expected, rng)
        lam = Float(lambda_expected).clamp(0.0, 8.0)
        l = Math.exp(-lam)
        k = 0
        p_accum = 1.0
        loop do
          k += 1
          p_accum *= rng.rand
          break if p_accum <= l
        end
        k - 1
      end
    end
  end
end
