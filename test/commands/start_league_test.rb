# frozen_string_literal: true

require_relative "../test_helper"
require "fileutils"
require "securerandom"
require "stringio"
require "pastel"
require "gaffer/database"
require "gaffer"
require "gaffer/commands/start_league"

describe Gaffer::Commands::StartLeague do
  def insert_club(name:, short:, rep: 60)
    Gaffer::Database.db[:clubs].insert(
      name: name,
      short_name: short,
      reputation: rep
    )
  end

  before do
    Gaffer::Database.disconnect if Gaffer::Database.connection
    @tmp_path = File.join(Dir.tmpdir, "gaffer_start_league_test_#{SecureRandom.hex(6)}.sqlite")
    FileUtils.rm_f(@tmp_path)
    ENV["GAFFER_DB_PATH"] = @tmp_path
    Gaffer::Database.prepare
  end

  after do
    Gaffer::Database.disconnect
    ENV.delete("GAFFER_DB_PATH")
    FileUtils.rm_f(@tmp_path) if defined?(@tmp_path) && @tmp_path
  end

  it "creates an active league, links clubs, and inserts a full fixture set" do
    insert_club(name: "Alpha Town", short: "ALP")
    insert_club(name: "Beta Rovers", short: "BET")
    insert_club(name: "Gamma Athletic", short: "GAM")
    insert_club(name: "Delta United", short: "DLT")

    pastel = Pastel.new
    io = StringIO.new
    _(Gaffer::Commands::StartLeague.run(pastel:, out: io)).must_equal :ok

    active = Gaffer::Repositories::LeagueRepository.active
    _(active).wont_be_nil
    _(active.status).must_equal :active
    _(active.current_gameweek).must_equal 1
    _(active.year).must_equal Gaffer::Commands::StartLeague::DEFAULT_FIRST_YEAR

    club_rows = Gaffer::Database.db[:clubs].order(:id).all
    _(club_rows.map { |r| r[:league_id] }.uniq).must_equal [active.id]

    n = 4
    expected_fixtures = n * (n - 1)
    _(Gaffer::Database.db[:fixtures].count).must_equal expected_fixtures
    _(Gaffer::Database.db[:fixtures].where(season_id: active.id).count).must_equal expected_fixtures

    buf = io.string
    _(buf).must_match(/Season #{active.year} is underway/)
    _(buf).must_match(/Gameweek 1 of 6/)
  end

  it "uses latest_year + 1 when a prior league exists" do
    insert_club(name: "Alpha Town", short: "ALP")
    insert_club(name: "Beta Rovers", short: "BET")
    Gaffer::Repositories::LeagueRepository.save(
      Gaffer::Domain::League.new(name: "Past", year: 2024, status: :complete, current_gameweek: 6)
    )

    _(Gaffer::Commands::StartLeague.run(pastel: Pastel.new, out: StringIO.new)).must_equal :ok
    _(Gaffer::Repositories::LeagueRepository.active.year).must_equal 2025
  end

  it "returns skipped when a league is already active" do
    insert_club(name: "Alpha Town", short: "ALP")
    insert_club(name: "Beta Rovers", short: "BET")

    io = StringIO.new
    _(Gaffer::Commands::StartLeague.run(pastel: Pastel.new, out: io)).must_equal :ok

    _(Gaffer::Commands::StartLeague.run(pastel: Pastel.new, out: StringIO.new)).must_equal :skipped_active
    _(Gaffer::Database.db[:leagues].count).must_equal 1
  end

  it "refuses odd club counts" do
    insert_club(name: "A", short: "AA")
    insert_club(name: "B", short: "BB")
    insert_club(name: "C", short: "CC")

    _(Gaffer::Commands::StartLeague.run(pastel: Pastel.new, out: StringIO.new)).must_equal :bad_club_count
    _(Gaffer::Repositories::LeagueRepository.active).must_be_nil
  end

  it "prints your first fixture when a manager is present" do
    _c1 = insert_club(name: "Home Side", short: "HOM")
    c2 = insert_club(name: "Away Wanderers", short: "AWY")
    Gaffer::Database.db[:managers].insert(display_name: "Boss", managed_club_id: c2)

    io = StringIO.new
    _(Gaffer::Commands::StartLeague.run(pastel: Pastel.new, out: io)).must_equal :ok
    _(io.string).must_match(/Your first fixture/)
    _(io.string).must_include("Away Wanderers (you)")
  end
end
