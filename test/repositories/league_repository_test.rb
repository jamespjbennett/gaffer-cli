# frozen_string_literal: true

require_relative "../test_helper"
require "fileutils"
require "securerandom"
require "gaffer/database"
require "gaffer"
require "gaffer/domain/league"

describe Gaffer::Repositories::LeagueRepository do
  before do
    Gaffer::Database.disconnect if Gaffer::Database.connection
    @tmp_path = File.join(Dir.tmpdir, "gaffer_league_test_#{SecureRandom.hex(6)}.sqlite")
    FileUtils.rm_f(@tmp_path)
    ENV["GAFFER_DB_PATH"] = @tmp_path
    Gaffer::Database.connect
    Gaffer::Database.migrate
  end

  after do
    Gaffer::Database.disconnect
    ENV.delete("GAFFER_DB_PATH")
    FileUtils.rm_f(@tmp_path) if defined?(@tmp_path) && @tmp_path
  end

  it "inserts and finds a league" do
    league = Gaffer::Domain::League.new(
      name: "Test League",
      year: 2026,
      status: :pending,
      current_gameweek: 1
    )
    saved = Gaffer::Repositories::LeagueRepository.save(league)
    _(saved.id).wont_be_nil
    _(saved.name).must_equal "Test League"
    _(saved.year).must_equal 2026
    _(saved.status).must_equal :pending

    again = Gaffer::Repositories::LeagueRepository.find(saved.id)
    _(again.year).must_equal 2026
  end

  it "returns active league" do
    Gaffer::Repositories::LeagueRepository.save(
      Gaffer::Domain::League.new(name: "Old", year: 2025, status: :complete, current_gameweek: 19)
    )
    Gaffer::Repositories::LeagueRepository.save(
      Gaffer::Domain::League.new(name: "Current", year: 2026, status: :active, current_gameweek: 3)
    )

    active = Gaffer::Repositories::LeagueRepository.active
    _(active.name).must_equal "Current"
    _(active.current_gameweek).must_equal 3
  end

  it "latest_year returns max year" do
    _(Gaffer::Repositories::LeagueRepository.latest_year).must_be_nil
    Gaffer::Repositories::LeagueRepository.save(
      Gaffer::Domain::League.new(name: "A", year: 2024, status: :complete, current_gameweek: 1)
    )
    Gaffer::Repositories::LeagueRepository.save(
      Gaffer::Domain::League.new(name: "B", year: 2027, status: :pending, current_gameweek: 1)
    )
    _(Gaffer::Repositories::LeagueRepository.latest_year).must_equal 2027
  end

  it "completed_ordered surfaces newest archived row first" do
    Gaffer::Repositories::LeagueRepository.save(
      Gaffer::Domain::League.new(name: "Old cap", year: 2025, status: :complete, current_gameweek: 99)
    )
    Gaffer::Repositories::LeagueRepository.save(
      Gaffer::Domain::League.new(name: "Recent cap", year: 2026, status: :complete, current_gameweek: 19)
    )

    ids = Gaffer::Repositories::LeagueRepository.completed_ordered.map(&:year)
    _(ids.first).must_equal 2026
  end

  it "find_for_calendar_year returns newest row for duplicate years" do
    Gaffer::Repositories::LeagueRepository.save(
      Gaffer::Domain::League.new(name: "First", year: 2028, status: :complete, current_gameweek: 18)
    )
    newer =
      Gaffer::Repositories::LeagueRepository.save(
        Gaffer::Domain::League.new(name: "Second", year: 2028, status: :active, current_gameweek: 1)
      )

    _(Gaffer::Repositories::LeagueRepository.find_for_calendar_year(2028).id).must_equal newer.id
  end
end
