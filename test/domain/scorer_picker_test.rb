# frozen_string_literal: true

require_relative "../test_helper"
require "gaffer/domain/player"
require "gaffer/domain/scorer_picker"

describe Gaffer::Domain::ScorerPicker do
  def pl(**kw)
    defaults = {
      id: nil,
      name: "X",
      age: 24,
      nationality: "ZZ",
      position: :mid,
      club_id: 1,
      pace: 70,
      shooting: 70,
      passing: 70,
      dribbling: 70,
      defending: 70,
      physical: 70,
      goalkeeping: 15,
      overall: 70,
      potential: 75,
      form: 6,
      morale: :okay,
      contract_years: 2,
      wage: 5
    }
    Gaffer::Domain::Player.new(**defaults.merge(kw))
  end

  describe ".pick" do
    it "returns empty when n_goals is zero" do
      xi = [pl(name: "A", position: :att)]
      _(Gaffer::Domain::ScorerPicker.pick(xi, 0, Random.new(1))).must_equal []
    end

    it "matches for the same RNG state" do
      xi = [
        pl(name: "Striker", position: :att, shooting: 90, pace: 80, dribbling: 76),
        pl(name: "Def", position: :def, shooting: 45, pace: 62, dribbling: 52)
      ]
      rng1 = Random.new(42)
      rng2 = Random.new(42)
      a = Gaffer::Domain::ScorerPicker.pick(xi, 8, rng1).map(&:name)
      b = Gaffer::Domain::ScorerPicker.pick(xi, 8, rng2).map(&:name)
      _(a).must_equal b
    end

    it "returns exactly n entries" do
      xi = 4.times.map { |i| pl(name: "P#{i}") }
      _(Gaffer::Domain::ScorerPicker.pick(xi, 12, Random.new(3)).size).must_equal 12
    end

    it "favours attackers over defenders when pace/shoot/dribbing are matched" do
      xi = [
        pl(name: "A", position: :att, shooting: 75, pace: 75, dribbling: 75),
        pl(name: "D", position: :def, shooting: 75, pace: 75, dribbling: 75)
      ]
      n = 3_500
      rng = Random.new(101)
      att_hits = n.times.count { Gaffer::Domain::ScorerPicker.pick(xi, 1, rng).first.name == "A" }
      _(att_hits).must_be :>, n * 0.54
    end
  end
end
