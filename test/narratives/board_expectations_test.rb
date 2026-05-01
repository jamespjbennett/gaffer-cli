# frozen_string_literal: true

require_relative "../test_helper"

require "gaffer/domain/club"
require "gaffer/narratives/board_expectations"

describe Gaffer::Narratives::BoardExpectations do
  def build_club(id:, board_target:, chairman_name: "C. Sinclair")
    Gaffer::Domain::Club.new(
      id: id,
      name: "Mersey Town FC",
      short_name: "MTF",
      league_id: nil,
      reputation: 70,
      budget: 1,
      wage_budget: 1,
      stadium: "Riverside",
      chairman_name: chairman_name,
      chairman_mood: :okay,
      board_target: board_target
    )
  end

  it "routes nil board_target through to mid-table copy" do
    _(Gaffer::Narratives::BoardExpectations.normalize_target(nil)).must_equal :mid_table
  end

  it "mentions the club and picks target-appropriate wording" do
    c_avoid = build_club(id: 3, board_target: :avoid_relegation)
    _(Gaffer::Narratives::BoardExpectations.message(club: c_avoid, manager_name: "Pat Smith")).must_include("Mersey Town FC")

    c_europe = build_club(id: 13, board_target: :europe)
    msg_e = Gaffer::Narratives::BoardExpectations.message(club: c_europe, manager_name: "Pat Smith")
    _(msg_e.downcase).must_match(/europe|continental/)

    c_title = build_club(id: 29, board_target: :title)
    msg_t = Gaffer::Narratives::BoardExpectations.message(club: c_title, manager_name: "Pat Smith")
    _(msg_t.downcase).must_match(/title|silverware/)

    _(Gaffer::Narratives::BoardExpectations.message(club: build_club(id: 5, board_target: :avoid_relegation), manager_name: "Alex")).must_include("Alex")
  end

  it "handles an absent chairman name in the opener" do
    c = build_club(id: 2, board_target: :avoid_relegation, chairman_name: nil)

    _(Gaffer::Narratives::BoardExpectations.opening_line(c)).must_include("Mersey Town FC")
    _(Gaffer::Narratives::BoardExpectations.opening_line(c)).must_include("the board")
  end

  it "is stable across repeated calls with the same club and manager" do
    c = build_club(id: 909, board_target: :mid_table)
    a = Gaffer::Narratives::BoardExpectations.message(club: c, manager_name: "Quinn")
    b = Gaffer::Narratives::BoardExpectations.message(club: c, manager_name: "Quinn")
    _(a).must_equal b
  end
end
