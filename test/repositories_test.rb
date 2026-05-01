# frozen_string_literal: true

require "fileutils"

require_relative "test_helper"
require "gaffer"

describe "Repositories" do
  def with_isolated_database
    prev = ENV["GAFFER_DB_PATH"]
    path = File.expand_path("../tmp/repositories.sqlite", __dir__)
    FileUtils.rm_f(path)
    FileUtils.mkdir_p(File.dirname(path))
    ENV["GAFFER_DB_PATH"] = path
    Gaffer::Database.disconnect
    Gaffer::Database.prepare
    yield Gaffer::Database.db
    Gaffer::Database.disconnect
    FileUtils.rm_f(path)
    ENV["GAFFER_DB_PATH"] = prev
    Gaffer::Database.disconnect unless prev
    nil
  end

  describe Gaffer::Repositories::ClubRepository do
    it "inserts and round-trips a club" do
      with_isolated_database do
        Club = Gaffer::Domain::Club
        Repo = Gaffer::Repositories::ClubRepository

        before = Repo.save(
          Club.new(
            name: "United Town",
            short_name: "UNT",
            league_id: 1,
            reputation: 60,
            budget: 5_000,
            wage_budget: 500,
            stadium: "Old Lane",
            chairman_name: "A. Citizen",
            chairman_mood: :concerned,
            board_target: :mid_table
          )
        )

        after = Repo.find(before.id)
        _(after.name).must_equal "United Town"
        _(after.chairman_mood).must_equal :concerned
        _(after.board_target).must_equal :mid_table

        Repo.save(Club.new(**before.to_h.merge(chairman_mood: :satisfied)))
        _(Repo.find(before.id).chairman_mood).must_equal :satisfied
      end
    end

    it "find_by_short_name normalises casing" do
      with_isolated_database do
        repo = Gaffer::Repositories::ClubRepository

        repo.save(
          Gaffer::Domain::Club.new(
            name: "United Town",
            short_name: "UNT",
            league_id: 1,
            reputation: 50,
            budget: 0,
            wage_budget: 0,
            stadium: "Lane",
            chairman_name: "X",
            chairman_mood: :okay,
            board_target: :mid_table
          )
        )

        got = repo.find_by_short_name("unt")
        _(got&.short_name).must_equal "UNT"
        _(repo.find_by_short_name("  ")).must_be_nil
      end
    end
  end

  describe Gaffer::Repositories::PlayerRepository do
    it "stores a player for a club" do
      with_isolated_database do
        repo_c = Gaffer::Repositories::ClubRepository
        repo_p = Gaffer::Repositories::PlayerRepository

        club = repo_c.save(Gaffer::Domain::Club.new(name: "Bee FC", short_name: "BEE", league_id: 1))

        ply = repo_p.save(
          Gaffer::Domain::Player.new(
            name: "Sam Bee",
            age: 24,
            nationality: "ENG",
            position: :mid,
            club_id: club.id,
            pace: 70,
            passing: 76,
            overall: 68,
            potential: 78,
            form: 6,
            morale: :happy,
            contract_years: 2,
            wage: 120
          )
        )

        got = repo_p.find(ply.id)
        _(got.position).must_equal :mid
        _(repo_p.for_club(club.id).first.name).must_equal "Sam Bee"
      end
    end
  end

  describe Gaffer::Repositories::FixtureRepository do
    it "stores a fixture linking two clubs" do
      with_isolated_database do
        repo_c = Gaffer::Repositories::ClubRepository
        repo_f = Gaffer::Repositories::FixtureRepository

        repo_c.save(Gaffer::Domain::Club.new(name: "A", short_name: "A", league_id: 1))
        repo_c.save(Gaffer::Domain::Club.new(name: "B", short_name: "B", league_id: 1))
        clubs = Gaffer::Database.db[:clubs].order(:id).all

        fx = repo_f.save(
          Gaffer::Domain::Fixture.new(
            season_id: 1,
            gameweek: 3,
            home_club_id: clubs.first[:id],
            away_club_id: clubs.last[:id],
            played: false
          )
        )

        _(fx.played?).must_equal false
        _(repo_f.for_season(1).size).must_equal 1
      end
    end

    it "collects participant club ids for a season roster" do
      with_isolated_database do
        repo_c = Gaffer::Repositories::ClubRepository
        repo_f = Gaffer::Repositories::FixtureRepository

        ids = []
        ids << repo_c.save(Gaffer::Domain::Club.new(name: "East", short_name: "EST", league_id: 99)).id
        ids << repo_c.save(Gaffer::Domain::Club.new(name: "North", short_name: "NRH", league_id: 99)).id
        ids << repo_c.save(Gaffer::Domain::Club.new(name: "West", short_name: "WST", league_id: 77)).id

        repo_f.save(
          Gaffer::Domain::Fixture.new(season_id: 7, gameweek: 1, home_club_id: ids[0], away_club_id: ids[1], played: false)
        )

        fetched = repo_f.club_ids_for_season(7).sort
        _(fetched).must_equal ids.first(2).sort
      end
    end
  end

  describe Gaffer::Repositories::MatchRepository do
    it "persists scores and JSON payloads" do
      with_isolated_database do
        repo_c = Gaffer::Repositories::ClubRepository
        repo_f = Gaffer::Repositories::FixtureRepository
        repo_m = Gaffer::Repositories::MatchRepository

        repo_c.save(Gaffer::Domain::Club.new(name: "A", short_name: "A", league_id: 1))
        repo_c.save(Gaffer::Domain::Club.new(name: "B", short_name: "B", league_id: 1))
        ids = Gaffer::Database.db[:clubs].select_map(:id)
        fx = repo_f.save(
          Gaffer::Domain::Fixture.new(
            season_id: 1,
            gameweek: 1,
            home_club_id: ids.fetch(0),
            away_club_id: ids.fetch(1),
            played: true
          )
        )

        repo_m.save(
          Gaffer::Domain::Match.new(
            fixture_id: fx.id,
            home_score: 2,
            away_score: 1,
            home_possession: 58,
            home_shots: 14,
            home_shots_ot: 7,
            away_shots: 9,
            away_shots_ot: 4,
            events: [{ "minute" => 12, "type" => "goal" }],
            player_ratings: { 42 => 8 },
            narrative: nil
          )
        )

        got = repo_m.for_fixture(fx.id)
        _(got.home_score).must_equal 2
        _(got.player_ratings.fetch(42)).must_equal 8
        _(got.events.first.fetch("minute")).must_equal 12
      end
    end
  end
end
