# frozen_string_literal: true

require_relative "../test_helper"
require "gaffer/domain/match_engine"
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
  end
end
