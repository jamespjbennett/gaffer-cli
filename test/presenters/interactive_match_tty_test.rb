# frozen_string_literal: true

require_relative "../test_helper"

require "pastel"
require "stringio"

require "gaffer/domain/club"
require "gaffer/domain/match_event"
require "gaffer/domain/player"
require "gaffer/presenters/interactive_match_tty"

describe Gaffer::Presenters::InteractiveMatchTty do
  describe ".minute_range_line" do
    it "reflects rollup windows used by #bucket/#span?" do
      m = Gaffer::Presenters::InteractiveMatchTty
      _(m.minute_range_line(5)).must_equal "1–5′"
      _(m.minute_range_line(15)).must_equal "6–15′"
      _(m.minute_range_line(45)).must_equal "36–45′"
      _(m.minute_range_line(55)).must_equal "46–55′"
      _(m.minute_range_line(90)).must_equal "81–90′"
    end
  end

  describe ".club_line_label" do
    it "shows name plus code when distinct" do
      c = mk_club(name: "Crescent Rovers", short: "CRS")
      lbl = Gaffer::Presenters::InteractiveMatchTty.club_line_label(c)
      _(lbl).must_equal "Crescent Rovers (CRS)"
    end
  end

  describe ".stream" do
    it "prints range headers and prefixes events with club" do
      home = mk_club(name: "Home Town", short: "HOM")
      away = mk_club(name: "Away Pool", short: "AWY")
      ply =
        Gaffer::Domain::Player.new(
          id: 1, name: "Sam Strike", age: 24, nationality: "T", position: :att, club_id: 1,
          pace: 70, shooting: 70, passing: 70, dribbling: 70, defending: 70,
          physical: 70, goalkeeping: 10, overall: 70, potential: 70, form: 5, morale: :okay,
          contract_years: 2, wage: 10
        )
      evt =
        Gaffer::Domain::MatchEvent.new(minute: 7, side: :away, type: :big_chance,
          player: ply, description: "unused")

      pastel = Pastel.new(enabled: false)
      io = StringIO.new
      Gaffer::Presenters::InteractiveMatchTty.stream(
        [evt], pastel, io, upto: 15, home_club: home, away_club: away
      )

      s = io.string
      _(s).must_include "6–15′"
      _(s).must_include "Away Pool (AWY)"
      _(s).must_include "Sam Strike"
    end
  end

  def mk_club(name:, short:)
    Gaffer::Domain::Club.new(id: 1, name:, short_name: short,
      league_id: 1, reputation: 50, budget: 0, wage_budget: 0, stadium: "",
      chairman_name: "", chairman_mood: :satisfied, board_target: :mid_table)
  end
end
