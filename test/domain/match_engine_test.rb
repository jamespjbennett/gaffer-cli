# frozen_string_literal: true

require_relative "../test_helper"
require "gaffer/domain/match_engine"
require "gaffer/domain/lineup"
require "gaffer/domain/club"
require "gaffer/domain/player"

describe Gaffer::Domain::MatchEngine do
  let(:engine) { Gaffer::Domain::MatchEngine.new }

  describe "#simulate" do
    # Synthetic players: same positional mix; "strong" has higher averages.
    builder = lambda do |base_ovr|
      skeleton = ([:gk] * 3) + ([:def] * 7) + ([:mid] * 7) + ([:att] * 6)

      skeleton.map.with_index do |pos, idx|
        ovr = (base_ovr + (idx % 7) - 3).clamp(40, 95)
        gk = pos == :gk ? ovr + 14 : [(ovr / 10.0).to_i, 55].max
        Gaffer::Domain::Player.new(
          name: "#{pos}_#{idx}",
          position: pos,
          age: 24,
          nationality: "ZZ",
          club_id: 1,
          pace: ovr + 10,
          shooting: ovr + 14,
          passing: ovr + 12,
          dribbling: ovr + (pos == :att ? +8 : -4),
          defending: pos == :gk ? 24 : pos == :att ? (ovr - 18).clamp(1, 99) : ovr + 8,
          physical: ovr + 5,
          goalkeeping: gk.to_i.clamp(1, 99),
          overall: ovr + 15,
          potential: ovr + 26,
          form: 6,
          morale: :okay,
          contract_years: 3,
          wage: base_ovr
        )
      end
    end

    club = lambda do |short:, rep:, name:, board:|
      Gaffer::Domain::Club.new(
        short_name: short,
        name: name,
        league_id: nil,
        reputation: rep,
        budget: 1,
        wage_budget: 1,
        stadium: "Test Ground",
        chairman_name: "X",
        chairman_mood: :okay,
        board_target: board
      )
    end

    strong_club = club.call(short: "BIG", rep: 88, name: "Big Town", board: :europe)
    weak_club = club.call(short: "SMB", rep: 58, name: "Small Town", board: :avoid_relegation)
    strong_team = builder.call(78)
    weak_team   = builder.call(56)

    it "matches itself when re-run with the same RNG seed" do
      a = engine.simulate(
        home_club: strong_club, home_players: strong_team,
        away_club: weak_club, away_players: weak_team,
        seed: 12_341
      )
      b = engine.simulate(
        home_club: strong_club, home_players: strong_team,
        away_club: weak_club, away_players: weak_team,
        seed: 12_341
      )
      _(a.to_h).must_equal(b.to_h)
    end

    it "shows higher effective ratings for Crowden-tier inputs than MBW-tier" do
      r = engine.simulate(
        home_club: strong_club, home_players: strong_team,
        away_club: weak_club, away_players: weak_team,
        seed: 7
      )
      _(r.home_attack_rating).must_be :>, r.away_attack_rating
      _(r.home_defense_rating).must_be :>, r.away_defense_rating
    end

    it "typically rewards the stronger seeded home XI over hundreds of deterministic fixtures" do
      home_points = (1..280).sum do |seed|
        r = engine.simulate(home_club: strong_club, home_players: strong_team, away_club: weak_club,
                              away_players: weak_team, seed: seed)
        r.home_score > r.away_score ? 3 : (r.home_score == r.away_score ? 1 : 0)
      end
      _(home_points).must_be :>, 490
    end

    # Tactic multipliers alter effective ratings → xG λ; same seed ⇒ same RNG noise, strict ordering on λ.

    it "raises home attack ratings and lowers home defence for all-out attack vs balanced" do
      r_bal = engine.simulate(
        home_club: strong_club, home_players: strong_team,
        away_club: weak_club, away_players: weak_team,
        home_tactic: :balanced, away_tactic: :balanced, seed: 99
      )
      r_ao = engine.simulate(
        home_club: strong_club, home_players: strong_team,
        away_club: weak_club, away_players: weak_team,
        home_tactic: :all_out_attack, away_tactic: :balanced, seed: 99
      )

      _(r_ao.home_attack_rating).must_be :>, r_bal.home_attack_rating
      _(r_ao.home_defense_rating).must_be :<, r_bal.home_defense_rating
    end

    it "does the inverse for park the bus vs balanced" do
      r_bal = engine.simulate(
        home_club: strong_club, home_players: strong_team,
        away_club: weak_club, away_players: weak_team,
        home_tactic: :balanced, away_tactic: :balanced, seed: 99
      )
      r_bus = engine.simulate(
        home_club: strong_club, home_players: strong_team,
        away_club: weak_club, away_players: weak_team,
        home_tactic: :park_the_bus, away_tactic: :balanced, seed: 99
      )

      _(r_bus.home_attack_rating).must_be :<, r_bal.home_attack_rating
      _(r_bus.home_defense_rating).must_be :>, r_bal.home_defense_rating
    end

    it "increases both teams expected goals λ when home goes all-out attack (more scored, softer at the back)" do
      (1..200).each do |seed|
        balanced = engine.simulate(
          home_club: strong_club, home_players: strong_team,
          away_club: weak_club, away_players: weak_team,
          home_tactic: :balanced, away_tactic: :balanced, seed: seed
        )
        ao = engine.simulate(
          home_club: strong_club, home_players: strong_team,
          away_club: weak_club, away_players: weak_team,
          home_tactic: :all_out_attack, away_tactic: :balanced, seed: seed
        )

        _(ao.home_xg_lambda).must_be :>, balanced.home_xg_lambda
        _(ao.away_xg_lambda).must_be :>, balanced.away_xg_lambda
      end
    end

    it "drops both λ when home parks the bus" do
      (1..200).each do |seed|
        balanced = engine.simulate(
          home_club: strong_club, home_players: strong_team,
          away_club: weak_club, away_players: weak_team,
          home_tactic: :balanced, away_tactic: :balanced, seed: seed
        )
        bus = engine.simulate(
          home_club: strong_club, home_players: strong_team,
          away_club: weak_club, away_players: weak_team,
          home_tactic: :park_the_bus, away_tactic: :balanced, seed: seed
        )

        _(bus.home_xg_lambda).must_be :<, balanced.home_xg_lambda
        _(bus.away_xg_lambda).must_be :<, balanced.away_xg_lambda
      end
    end

    it "all-out attack averages more goals at both ends than balanced over many seeds (Poisson, not λ only)" do
      n = 400
      sum_bal = [0.0, 0.0]
      sum_ao = [0.0, 0.0]

      (1..n).each do |seed|
        b = engine.simulate(
          home_club: strong_club, home_players: strong_team,
          away_club: weak_club, away_players: weak_team,
          home_tactic: :balanced, away_tactic: :balanced, seed: seed
        )
        a = engine.simulate(
          home_club: strong_club, home_players: strong_team,
          away_club: weak_club, away_players: weak_team,
          home_tactic: :all_out_attack, away_tactic: :balanced, seed: seed
        )
        sum_bal[0] += b.home_score
        sum_bal[1] += b.away_score
        sum_ao[0] += a.home_score
        sum_ao[1] += a.away_score
      end

      _(sum_ao[0] / n).must_be :>, sum_bal[0] / n
      _(sum_ao[1] / n).must_be :>, sum_bal[1] / n
    end

    it "changes home strength and λ when swapping one outfielder on the XI (same seed elsewhere)" do
      away_xi = Gaffer::Domain::Lineup.pick_best_xi(weak_team)
      stock_home = Gaffer::Domain::Lineup.pick_best_xi(strong_team)

      weak_mid = Gaffer::Domain::Player.new(
        name: "Weak bench mid",
        position: :mid,
        age: 22,
        nationality: "ZZ",
        club_id: 1,
        pace: 38,
        shooting: 36,
        passing: 39,
        dribbling: 37,
        defending: 40,
        physical: 42,
        goalkeeping: 12,
        overall: 44,
        potential: 48,
        form: 4,
        morale: :okay,
        contract_years: 2,
        wage: 3
      )

      alt_home = stock_home.dup
      alt_home[6] = weak_mid

      _(alt_home.map(&:object_id)).wont_equal stock_home.map(&:object_id)

      base = engine.simulate(
        home_club: strong_club, home_players: stock_home,
        away_club: weak_club, away_players: away_xi,
        home_tactic: :balanced, away_tactic: :balanced,
        seed: 77_777
      )
      tweaked = engine.simulate(
        home_club: strong_club, home_players: alt_home,
        away_club: weak_club, away_players: away_xi,
        home_tactic: :balanced, away_tactic: :balanced,
        seed: 77_777
      )

      _(tweaked.home_attack_rating).wont_equal base.home_attack_rating
      _(tweaked.home_defense_rating).wont_equal base.home_defense_rating
      _(tweaked.home_xg_lambda).wont_equal base.home_xg_lambda
      _(tweaked.away_xg_lambda).wont_equal base.away_xg_lambda
    end
  end
end
