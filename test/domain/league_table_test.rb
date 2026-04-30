# frozen_string_literal: true

require_relative "../test_helper"
require "gaffer/domain/club"
require "gaffer/domain/league_table"

describe Gaffer::Domain::LeagueTable do
  def club_attrs(id:, name:)
    {
      id: id,
      name: name,
      short_name: name[..2].upcase,
      league_id: 1,
      reputation: 50,
      budget: 0,
      wage_budget: 0,
      stadium: nil,
      chairman_name: nil,
      chairman_mood: nil,
      board_target: nil
    }
  end

  let(:alfa) { Gaffer::Domain::Club.new(**club_attrs(id: 10, name: "Alpha AFC")) }
  let(:beta) { Gaffer::Domain::Club.new(**club_attrs(id: 11, name: "Beta Borough")) }

  it "applies classic 3-1-0 points" do
    rows = Gaffer::Domain::LeagueTable.standings_for(
      clubs: [alfa, beta],
      results: [{ home_club_id: alfa.id, away_club_id: beta.id, home_score: 2, away_score: 1 }]
    )
    winner = rows.find { |r| r.club.id == alfa.id }
    loser = rows.find { |r| r.club.id == beta.id }

    _(winner.points).must_equal 3
    _(winner.played).must_equal 1
    _(winner.gf).must_equal 2
    _(winner.ga).must_equal 1

    _(loser.points).must_equal 0
    _(loser.lost).must_equal 1
  end

  it "handles draws" do
    rows = Gaffer::Domain::LeagueTable.standings_for(
      clubs: [alfa, beta],
      results: [{ home_club_id: alfa.id, away_club_id: beta.id, home_score: 0, away_score: 0 }]
    )
    _(rows.all? { |r| r.points == 1 && r.drawn == 1 }).must_equal true
  end

  it "ranks richer goal difference above clubs level on points" do
    gamma = Gaffer::Domain::Club.new(**club_attrs(id: 12, name: "Gamma Gate"))
    fixtures = [
      { home_club_id: gamma.id, away_club_id: alfa.id, home_score: 0, away_score: 10 },
      { home_club_id: beta.id, away_club_id: gamma.id, home_score: 2, away_score: 1 }
    ]
    ordered = Gaffer::Domain::LeagueTable.standings_for(clubs: [alfa, beta, gamma], results: fixtures)
    _(ordered.take(2).map { |row| row.club.id }).must_equal [alfa.id, beta.id]
  end

  it "indexes positions deterministically" do
    rows = Gaffer::Domain::LeagueTable.standings_for(
      clubs: [alfa, beta],
      results: [{ home_club_id: beta.id, away_club_id: alfa.id, home_score: 0, away_score: 9 }]
    )
    pos = Gaffer::Domain::LeagueTable.positions_by_club(rows)
    _(pos[alfa.id]).must_equal 1
    _(pos[beta.id]).must_equal 2
  end
end
