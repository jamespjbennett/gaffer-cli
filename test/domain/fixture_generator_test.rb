# frozen_string_literal: true

require_relative "../test_helper"
require "gaffer/domain/fixture_generator"

describe Gaffer::Domain::FixtureGenerator do
  let(:gen) { Gaffer::Domain::FixtureGenerator }

  it "raises on odd team count" do
    _(proc { gen.generate(club_ids: [1, 2, 3], league_id: 99) }).must_raise ArgumentError
  end

  it "raises on duplicate club ids" do
    _(proc { gen.generate(club_ids: [1, 1, 2, 4], league_id: 1) }).must_raise ArgumentError
  end

  it "produces 18 gameweeks, 90 matches, five per round for 10 teams with correct league marker" do
    ids = (1..10).to_a
    fx = gen.generate(club_ids: ids, league_id: 2026)

    _(fx.size).must_equal 90

    _(fx.all? do |m|
      m.id.nil? && m.played == false && m.season_id == 2026 &&
        ids.include?(m.home_club_id) && ids.include?(m.away_club_id) &&
        m.home_club_id != m.away_club_id
    end).must_equal true

    by_gw = fx.group_by(&:gameweek)
    _(by_gw.keys.sort).must_equal ((1..18).to_a)
    by_gw.each_value do |rnd|
      _(rnd.size).must_equal 5
    end
  end

  it "covers each unordered pairing once before return leg then once more with swapped venues" do
    ids = (11..14).to_a # n = 4 → 12 fixtures, 6 per half

    fx = gen.generate(club_ids: ids, league_id: 42)
    _(fx.size).must_equal 12

    combos = ids.combination(2).map(&:sort).freeze
    half = ids.size.pred

    first = fx.select { |m| m.gameweek <= half }
    back = fx.select { |m| m.gameweek > half }
    _(first.size).must_equal 6
    _(back.size).must_equal 6

    fk = first.map { |m| [m.home_club_id, m.away_club_id].sort }
    _(fk.uniq.sort).must_equal combos.sort

    combos.each do |a, b|
      as_home_vs_b = fx.count { |m| m.home_club_id == a && m.away_club_id == b }
      _(as_home_vs_b).must_equal 1
      as_home_vs_a = fx.count { |m| m.home_club_id == b && m.away_club_id == a }
      _(as_home_vs_a).must_equal 1
    end
  end

  it "minimal two-team double round-robin" do
    fx = gen.generate(club_ids: [101, 7], league_id: 2)
    _(fx.sort_by(&:gameweek).map { |m| [m.home_club_id, m.away_club_id] }).must_equal [[101, 7], [7, 101]]
  end
end
