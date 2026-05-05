# frozen_string_literal: true

require_relative "../test_helper"

require "gaffer/domain/match_engine"
require "gaffer/domain/match_runner"
require "gaffer/domain/club"
require "gaffer/domain/player"

describe Gaffer::Domain::MatchRunner do
  def side(name, id)
    Gaffer::Domain::Club.new(
      id: id,
      name: name,
      short_name: name[0, 3].upcase,
      league_id: 1,
      reputation: 60,
      budget: 0,
      wage_budget: 0,
      stadium: "",
      chairman_name: "",
      chairman_mood: :satisfied,
      board_target: :mid_table
    )
  end

  def fake_xi(offset)
    slots = %i[gk def def def def mid mid mid att att att]
    slots.each_with_index.map do |pos, i|
      Gaffer::Domain::Player.new(
        id: offset + i,
        name: "#{pos}#{i}",
        age: 24,
        nationality: "Test",
        position: pos,
        club_id: 1,
        pace: 71,
        shooting: 72,
        passing: 73,
        dribbling: 74,
        defending: 68,
        physical: 69,
        goalkeeping: pos == :gk ? 80 : 10,
        overall: 71,
        potential: 76,
        form: 6,
        morale: :okay,
        contract_years: 2,
        wage: 10
      )
    end
  end

  let(:home_club) { side("Homers", 10) }
  let(:away_club) { side("Awayos", 11) }
  let(:home_players) { fake_xi(100) }
  let(:away_players) { fake_xi(200) }
  let(:engine) { Gaffer::Domain::MatchEngine.new }

  it "is deterministic for a fixed seed" do
    a = build_result(12_345)
    b = build_result(12_345)
    _(a.home_score).must_equal b.home_score
    _(a.away_score).must_equal b.away_score
    _(a.home_scorers.size).must_equal a.home_score
    _(a.away_scorers.size).must_equal a.away_score
  end

  it "plays 90 minutes and updates snapshot" do
    run = fresh
    snap = run.play_to_minute(90)
    _(snap.minute).must_equal 90
    res = run.finalize_match_result
    _(res.home_score + res.away_score).must_equal run.events.count { |e| e.type == :goal }
  end

  def build_result(seed)
    r = fresh(seed: seed)
    r.play_to_minute(90)
    r.finalize_match_result
  end

  def fresh(seed: 77_777)
    Gaffer::Domain::MatchRunner.new(
      home_club: home_club,
      away_club: away_club,
      home_players: home_players,
      away_players: away_players,
      home_tactic: :balanced,
      away_tactic: :balanced,
      seed: seed,
      engine: engine
    )
  end
end
