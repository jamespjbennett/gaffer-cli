# frozen_string_literal: true

require_relative "../test_helper"

require "pastel"
require "stringio"

require "gaffer/domain/club"
require "gaffer/domain/halftime_report"
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

  describe ".dossier" do
    it "prints Your squad with two scored rows (managed only)" do
      hot = { player: dossier_pl("Zed One"), score: 2.12 }
      cold = { player: dossier_pl("Two Sad"), score: 0.88 }
      rep = dossier_report(hot, cold)
      io = StringIO.new
      pastel = Pastel.new(enabled: false)
      Gaffer::Presenters::InteractiveMatchTty.dossier(rep, pastel, io)
      body = io.string
      _(body).must_include "Your squad"
      _(body).must_include "Playing well"
      _(body).must_include "Zed One"
      _(body).must_include "2.1"
      _(body).must_include "Struggling"
      _(body).must_include "Two Sad"
      _(body).must_include "0.9"
      _(body).wont_include "One to watch"
    end
  end

  def dossier_pl(name)
    Gaffer::Domain::Player.new(
      id: 1, name:, age: 22, nationality: "T", position: :mid, club_id: 1,
      pace: 60, shooting: 60, passing: 60, dribbling: 60, defending: 60,
      physical: 60, goalkeeping: 5, overall: 60, potential: 65, form: 6, morale: :happy,
      contract_years: 2, wage: 5
    )
  end

  def dossier_report(hot, cold)
    Gaffer::Domain::HalftimeReport.new(
      snapshot: nil,
      managed_is_home: true,
      managed_label: "Us",
      opponent_label: "Them",
      managed_hot: hot,
      managed_cold: cold,
      opponent_hot: { player: dossier_pl("Opp Hot"), score: 9.9 },
      opponent_cold: { player: dossier_pl("Opp Cold"), score: 0.1 },
      managed_strength_lines: [],
      managed_weak_lines: [],
      opponent_strength_lines: [],
      opponent_weak_lines: []
    )
  end

  def mk_club(name:, short:)
    Gaffer::Domain::Club.new(id: 1, name:, short_name: short,
      league_id: 1, reputation: 50, budget: 0, wage_budget: 0, stadium: "",
      chairman_name: "", chairman_mood: :satisfied, board_target: :mid_table)
  end
end
