# frozen_string_literal: true

require_relative "../test_helper"
require "gaffer/domain/lineup"
require "gaffer/domain/player"

describe Gaffer::Domain::Lineup do
  def pl(id, pos, overall)
    Gaffer::Domain::Player.new(
      id:, name: "#{pos}_#{id}", age: 24, nationality: "T", position: pos,
      club_id: 1, pace: 60, shooting: 60, passing: 60, dribbling: 60,
      defending: 60, physical: 60, goalkeeping: pos == :gk ? 80 : 20,
      overall:, potential: overall + 5, form: 6, morale: :okay,
      contract_years: 2, wage: 5
    )
  end

  it "picks eleven unique players following 4-3-3 shape from a full seeded roster shape" do
    squad = []
    3.times { |i| squad << pl(i + 1, :gk, 50 + i) }
    7.times { |i| squad << pl(10 + i, :def, 60 + (i % 3)) }
    squad << pl(999, :def, 93)
    7.times { |i| squad << pl(40 + i, :mid, 58 + i) }
    6.times { |i| squad << pl(70 + i, :att, 59 + (i % 4)) }

    _(squad.size).must_equal 24

    xi = Gaffer::Domain::Lineup.pick_best_xi(squad)

    _(xi.size).must_equal 11
    _(xi.map(&:id).uniq.size).must_equal 11
    _(xi.count { |p| p.position == :gk }).must_equal 1
    _(xi.count { |p| p.position == :def }).must_equal 4
    _(xi.count { |p| p.position == :mid }).must_equal 3
    _(xi.count { |p| p.position == :att }).must_equal 3
    _(xi.first.id).must_equal 3
    _(xi.map(&:id).include?(999)).must_equal true
  end
end
