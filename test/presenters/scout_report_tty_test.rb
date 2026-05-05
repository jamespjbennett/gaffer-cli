# frozen_string_literal: true

require_relative "../test_helper"

require "pastel"
require "stringio"

require "gaffer/domain/scout_report"
require "gaffer/presenters/scout_report_tty"

describe Gaffer::Presenters::ScoutReportTty do
  def club(name: "Rovers")
    Gaffer::Domain::Club.new(id: 1, name: name, short_name: "ROV", league_id: 1, reputation: 50, budget: 0, wage_budget: 0,
      stadium: "", chairman_name: "", chairman_mood: :satisfied, board_target: :mid_table)
  end

  def player(name)
    Gaffer::Domain::Player.new(
      id: 9, name:, age: 22, nationality: "Test", position: :att, club_id: 1,
      pace: 70, shooting: 70, passing: 70, dribbling: 70, defending: 70,
      physical: 70, goalkeeping: 10, overall: 70, potential: 75, form: 5, morale: :okay,
      contract_years: 2, wage: 10
    )
  end

  def report(overrides = {})
    defaults = {
      opponent: club(name: "Millbrook Wanderers"),
      managed_club: club(name: "Us"),
      gameweek: 2,
      hosting_managed: false,
      league_position: 9,
      league_size: 10,
      played: 4,
      manager_league_position: 3,
      manager_played: 4,
      manager_points: 12,
      opponent_points: 8,
      recent_form: %i[w l d w l],
      attack_rating: 42.1,
      defence_rating: 61.7,
      our_attack_rating: 48.0,
      our_defence_rating: 55.0,
      top_scorer: { player: player("Norwood"), goals: 4 },
      watch_focus: { player: player("Other"), kind: :livewire, goals: nil }
    }
    Gaffer::Domain::ScoutReport.new(**defaults.merge(overrides))
  end

  let(:pastel) { Pastel.new(enabled: false) }
  let(:out) { StringIO.new }

  it "renders position, form glyphs, ratings, and top scorer" do
    Gaffer::Presenters::ScoutReportTty.render(report, pastel:, out:)
    s = out.string
    _(s).must_include "Scouting: Millbrook Wanderers"
    _(s).must_include "9th of 10"
    _(s).must_include "(4 played)"
    _(s).must_include "W2 D1 L2 last 5"
    _(s).must_include "42.1"
    _(s).must_include "61.7"
    _(s).must_include "Norwood"
    _(s).must_include "4 goals"
  end

  it "shows no-results form when nothing played" do
    Gaffer::Presenters::ScoutReportTty.render(
      report(played: 0, recent_form: [], manager_played: 0),
      pastel:, out:
    )
    _(out.string).must_include "No results yet"
  end

  it "shows none yet when no top scorer" do
    Gaffer::Presenters::ScoutReportTty.render(report(top_scorer: nil), pastel:, out:)
    _(out.string).must_include "None yet"
  end
end
