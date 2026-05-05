# frozen_string_literal: true

require_relative "../test_helper"
require "gaffer/domain/club"
require "gaffer/narratives/board_reaction"

describe Gaffer::Narratives::BoardReaction do
  def mk_club(sym, mood: :satisfied)
    Gaffer::Domain::Club.new(id: sym.to_s.bytes.sum, name: "#{sym}", short_name: sym.to_s,
      league_id: 1, reputation: 50, budget: 0, wage_budget: 0, stadium: "",
      chairman_name: "", chairman_mood: mood, board_target: :mid_table)
  end

  def message_for(managed:, opp:, hs:, aos:, hosting:, mgr_r:, opp_r:, size: 10)
    c = Gaffer::Narratives::BoardReaction::Context.new(
      managed_club: managed,
      opponent_club: opp,
      home_score: hs,
      away_score: aos,
      hosting_managed: hosting,
      managed_rank: mgr_r,
      opponent_rank: opp_r,
      league_size: size
    )
    Gaffer::Narratives::BoardReaction.message(c)
  end

  it "home win to nil praises defence" do
    m = message_for(managed: mk_club(:us), opp: mk_club(:them), hs: 3, aos: 0,
      hosting: true, mgr_r: 6, opp_r: 8).downcase
    _(m).must_include("today's")
    _(m).must_include("3-0")
    _(m).must_include("home")
    _(m).must_include("victory")
    _(m).must_include("against them")
    _(m).must_include("nil")
    _(m).must_include("back")
  end

  it "narrow away defeat to top-three stays gentle" do
    m = message_for(managed: mk_club(:us), opp: mk_club(:top), hs: 1, aos: 0,
      hosting: false, mgr_r: 10, opp_r: 1).downcase
    _(m).must_include("1-0")
    _(m).must_include("away")
    _(m).must_include("against top")
    _(m).must_include("margins") # detail body
    _(m).must_include("tough ground")
  end

  it "away draw at strong side earns credit" do
    m = message_for(managed: mk_club(:us), opp: mk_club(:top), hs: 0, aos: 0,
      hosting: false, mgr_r: 9, opp_r: 2).downcase
    _(m).must_include("0-0")
    _(m).must_include("away draw")
    _(m).must_include("character")
    _(m).must_include("top")
  end

  it "heavy loss plus furious chairman sharpens greeting" do
    mui = mk_club(:us, mood: :furious)
    m = message_for(managed: mui, opp: mk_club(:them), hs: 4, aos: 0,
      hosting: false, mgr_r: 5, opp_r: 6)
    _(m.downcase).must_include("conced") # battered body copy
    _(m).must_include("unacceptable")
    _(m.downcase).must_include("4-0")
  end
end
