# frozen_string_literal: true

require_relative "../../test_helper"
require "gaffer/domain/player"
require "gaffer/domain/club"
require "gaffer/commands/support/scout_coaching_notables"

describe "Gaffer::Commands::Support::ScoutCoachingNotables" do
  let(:club) do
    Gaffer::Domain::Club.new(id: 1, name: "Bee FC", short_name: "BEE", league_id: 9, reputation: 50)
  end

  def pl(name:, form:, morale: :okay)
    Gaffer::Domain::Player.new(
      name: name,
      age: 22,
      nationality: "X",
      position: :mid,
      club_id: 1,
      pace: 70,
      shooting: 70,
      passing: 70,
      dribbling: 70,
      defending: 70,
      physical: 70,
      goalkeeping: 20,
      overall: 70,
      potential: 75,
      form: form,
      morale: morale,
      contract_years: 2,
      wage: 5
    )
  end

  it "picks three highest-form players strictly above neutral" do
    xi = [
      pl(name: "Aa", form: 6),
      pl(name: "Bb", form: 10),
      pl(name: "Cc", form: 10),
      pl(name: "Dd", form: 9),
      pl(name: "Ee", form: 5),
      pl(name: "Lf", form: 3),
      pl(name: "Gg", form: 7),
      pl(name: "Hh", form: 8)
    ]
    ctx = Gaffer::Commands::Support::ScoutCoachingNotables.context(managed_club: club, managed_xi: xi)
    names = ctx.rising.map(&:name)
    _(names).must_equal ["Bb", "Cc", "Dd"]
  end

  it "picks three lowest-form players strictly below neutral" do
    xi = [
      pl(name: "Zz", form: 2),
      pl(name: "Yy", form: 4),
      pl(name: "Xx", form: 8),
      pl(name: "Ww", form: 1),
      pl(name: "Vv", form: 3),
      pl(name: "Uu", form: 5)
    ]
    ctx = Gaffer::Commands::Support::ScoutCoachingNotables.context(managed_club: club, managed_xi: xi)
    names = ctx.falling.map(&:name)
    _(names).must_equal ["Ww", "Zz", "Vv"]
  end

  it "returns empty lists when xi all at neutral form" do
    xi = 11.times.map { |i| pl(name: "P#{i}", form: 5) }
    ctx = Gaffer::Commands::Support::ScoutCoachingNotables.context(managed_club: club, managed_xi: xi)
    _(ctx.notable?).must_equal false
  end

  it "ties break on name asc" do
    xi = [pl(name: "B", form: 8), pl(name: "A", form: 8), pl(name: "C", form: 9)]
    ctx = Gaffer::Commands::Support::ScoutCoachingNotables.context(managed_club: club, managed_xi: xi)
    _(ctx.rising.map(&:name)).must_equal ["C", "A", "B"]
  end
end
