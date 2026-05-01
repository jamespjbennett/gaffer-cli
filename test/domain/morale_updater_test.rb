# frozen_string_literal: true

require_relative "../test_helper"
require "gaffer/domain/player"
require "gaffer/domain/match_result"
require "gaffer/domain/morale_round_row"
require "gaffer/domain/morale_updater"

describe Gaffer::Domain::MoraleUpdater do
  base = lambda do |id, slot|
    Gaffer::Domain::Player.new(
      id: id,
      name: "p#{id}",
      age: 24,
      nationality: "T",
      position: slot,
      club_id: 1,
      pace: 70,
      shooting: 70,
      passing: 70,
      dribbling: 70,
      defending: 80 - id % 11,
      physical: 70,
      goalkeeping: slot == :gk ? 75 : 20,
      overall: 70,
      potential: 75,
      form: 6,
      morale: :okay,
      contract_years: 2,
      wage: 5
    )
  end

  let(:gk) { base.call(1, :gk) }
  let(:defs) { (2..5).map { |i| base.call(i, :def) } }
  let(:mids) { (6..8).map { |i| base.call(i, :mid) } }
  let(:atts) { (9..11).map { |i| base.call(i, :att) } }
  let(:home_xi) { [gk] + defs + mids + atts }

  let(:gk_a) { Gaffer::Domain::Player.new(**gk.to_h.merge(id: 101, club_id: 2)) }
  let(:away_xi_ordered) do
    [gk_a] +
      defs.map.with_index do |pl, idx|
        Gaffer::Domain::Player.new(**pl.to_h.merge(id: pl.id + 100, club_id: 2, defending: 50 + idx))
      end +
      mids.map { |pl| Gaffer::Domain::Player.new(**pl.to_h.merge(id: pl.id + 100, club_id: 2)) } +
      atts.map { |pl| Gaffer::Domain::Player.new(**pl.to_h.merge(id: pl.id + 100, club_id: 2)) }
  end

  def row_for(result)
    Gaffer::Domain::MoraleRoundRow.new(fixture: nil, result: result, home_xi: home_xi, away_xi: away_xi_ordered)
  end

  let(:players_by_id) do
    (home_xi + away_xi_ordered).each_with_object({}) { |pl, h| h[pl.id] = pl }
  end

  it "drops midfield form toward five on win without scoring" do
    mid = mids.first
    r =
      Gaffer::Domain::MatchResult.new(
        home_score: 1,
        away_score: 0,
        home_xg_lambda: 1.0,
        away_xg_lambda: 1.0,
        home_attack_rating: 1.0,
        home_defense_rating: 1.0,
        away_attack_rating: 1.0,
        away_defense_rating: 1.0,
        home_scorers: [atts.first],
        away_scorers: []
      )
    out = Gaffer::Domain::MoraleUpdater.call(round_fixtures: [row_for(r)], players_by_id:, rng: Random.new(1))
    _(out[mid.id][:form]).must_equal 5
    _(out[mid.id][:morale]).must_equal :happy
  end

  it "bumps scorer form and shifts morale" do
    st = atts.first
    r =
      Gaffer::Domain::MatchResult.new(
        home_score: 2,
        away_score: 0,
        home_xg_lambda: 1.0,
        away_xg_lambda: 1.0,
        home_attack_rating: 1.0,
        home_defense_rating: 1.0,
        away_attack_rating: 1.0,
        away_defense_rating: 1.0,
        home_scorers: [st, st],
        away_scorers: []
      )
    out = Gaffer::Domain::MoraleUpdater.call(round_fixtures: [row_for(r)], players_by_id:, rng: Random.new(2))
    _(out[st.id][:form]).must_equal 7
    _(out[st.id][:morale]).must_equal :ecstatic
  end

  it "hands keeper two-form hit when conceding two" do
    r =
      Gaffer::Domain::MatchResult.new(
        home_score: 2,
        away_score: 0,
        home_xg_lambda: 1.0,
        away_xg_lambda: 1.0,
        home_attack_rating: 1.0,
        home_defense_rating: 1.0,
        away_attack_rating: 1.0,
        away_defense_rating: 1.0,
        home_scorers: [atts.first, atts.last],
        away_scorers: []
      )
    out = Gaffer::Domain::MoraleUpdater.call(round_fixtures: [row_for(r)], players_by_id:, rng: Random.new(3))
    _(out[gk_a.id][:form]).must_equal 4
  end

  it "gives defenders clean-sheet credit" do
    r =
      Gaffer::Domain::MatchResult.new(
        home_score: 0,
        away_score: 1,
        home_xg_lambda: 1.0,
        away_xg_lambda: 1.0,
        home_attack_rating: 1.0,
        home_defense_rating: 1.0,
        away_attack_rating: 1.0,
        away_defense_rating: 1.0,
        home_scorers: [],
        away_scorers: [away_xi_ordered.last]
      )
    out = Gaffer::Domain::MoraleUpdater.call(round_fixtures: [row_for(r)], players_by_id:, rng: Random.new(4))
    ad = defs.map { |pl| away_xi_ordered.detect { |a| a.id == pl.id + 100 } }
    _(ad.all? { |pl| out[pl.id][:form] > 6 }).must_equal(true)
  end
end
