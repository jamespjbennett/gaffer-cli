# frozen_string_literal: true

require_relative "../test_helper"
require "gaffer/commands/support/gameweek_dugout_kw"

describe Gaffer::Commands::Support::GameweekDugoutKw do
  Gw = Struct.new(
    :suggested_xi,
    :full_squad,
    :managed_club,
    :gameweek,
    :opponent_name_short,
    :hosting_managed,
    keyword_init: true
  )

  it "packs scout and coaching alongside fixture fields for resolve" do
    st = Gw.new(
      suggested_xi: %i[a b],
      full_squad: %i[f],
      managed_club: :club,
      gameweek: 7,
      opponent_name_short: "OPP",
      hosting_managed: true
    )

    scout = Object.new
    coaching = Object.new

    kw = Gaffer::Commands::Support::GameweekDugoutKw.resolve_args(
      state: st, scout: scout, coaching: coaching, manager_lineup: [:xi]
    )

    _(kw.fetch(:scout)).must_equal scout
    _(kw.fetch(:coaching)).must_equal coaching
    _(kw.fetch(:preset)).must_equal [:xi]
    _(kw.fetch(:suggested_xi)).must_equal %i[a b]
    _(kw.fetch(:full_squad)).must_equal %i[f]
    _(kw.fetch(:club)).must_equal :club
    _(kw.fetch(:gameweek)).must_equal 7
    _(kw.fetch(:opponent)).must_equal "OPP"
    _(kw.fetch(:hosting)).must_equal true
  end
end
