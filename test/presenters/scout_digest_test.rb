# frozen_string_literal: true

require_relative "../test_helper"

require "pastel"
require "stringio"

require "gaffer/domain/scout_report"
require "gaffer/presenters/scout_digest"

describe "Gaffer::Presenters::ScoutDigest" do
  ScoutDigest = Gaffer::Presenters::ScoutDigest

  def club(name: "Towns")
    Gaffer::Domain::Club.new(id: 1, name:, short_name: "TWN", league_id: 1, reputation: 50, budget: 0,
      wage_budget: 0, stadium: "", chairman_name: "", chairman_mood: :satisfied,
      board_target: :mid_table)
  end

  def player(nm)
    Gaffer::Domain::Player.new(
      id: 2, name: nm, age: 21, nationality: "T", position: :att, club_id: 1,
      pace: 60, shooting: 60, passing: 60, dribbling: 60, defending: 50,
      physical: 55, goalkeeping: 5, overall: 60, potential: 65, form: 5, morale: :okay,
      contract_years: 2, wage: 5
    )
  end

  def dossier(**overrides)
    Gaffer::Domain::ScoutReport.new(
      opponent: club(name: "Rivals"),
      managed_club: club(name: "Us"),
      gameweek: 3,
      hosting_managed: true,
      league_position: 2,
      league_size: 10,
      played: 5,
      manager_league_position: 6,
      manager_played: 5,
      manager_points: 7,
      opponent_points: 12,
      recent_form: %i[w d w],
      attack_rating: 77.75,
      defence_rating: 99.0,
      our_attack_rating: 70,
      our_defence_rating: 70,
      top_scorer: { player: player("Milo Price"), goals: 5 },
      watch_focus: { player: player("Warned"), kind: :scorer, goals: 5 },
      **overrides
    )
  end

  let(:pastel) { Pastel.new(enabled: false) }

  it "prints opponent stripe, form+rates, watcher line, rule" do
    io = StringIO.new
    ScoutDigest.render(dossier, pastel:, out: io)
    body = io.string
    _(body).must_include "Rivals"
    _(body).must_include "2nd of 10"
    _(body).must_include "(5 played)"
    _(body.downcase).must_include "atk"
    _(body).must_include "77.8"
    _(body).must_include "99.0"
    _(body).must_include "Warned"
    _(body).must_include(Gaffer::Presenters::ScoutDigest::WIDTH.times.map { "─" }.join)
  end

  it "no-op when report nil" do
    io = StringIO.new
    ScoutDigest.render(nil, pastel:, out: io)
    _(io.string).must_be_empty
  end

  it "falls back to top scorer when watch_focus absent" do
    io = StringIO.new
    ScoutDigest.render(dossier(watch_focus: nil), pastel:, out: io)
    _(io.string).must_include "Milo Price"
    _(io.string.downcase).must_include "top scorer"
  end
end
