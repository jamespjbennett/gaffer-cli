# frozen_string_literal: true

require "fileutils"
require_relative "test_helper"
require "gaffer/database"

describe "database migrations" do
  attr_reader :db_path

  before do
    @db_path = File.expand_path("../tmp/schema_test.sqlite", __dir__)
    FileUtils.rm_f(db_path)
    FileUtils.mkdir_p(File.dirname(db_path))

    ENV["GAFFER_DB_PATH"] = db_path
    Gaffer::Database.disconnect
    Gaffer::Database.migrate
  end

  after do
    Gaffer::Database.disconnect
    ENV.delete("GAFFER_DB_PATH")
    FileUtils.rm_f(db_path)
  end

  it "creates clubs, players, fixtures, matches tables with expected columns" do
    _(Gaffer::Database.db.tables.sort).must_equal(%i[clubs fixtures matches players schema_info].sort)

    club_columns = Gaffer::Database.db[:clubs].columns
    _(club_columns).must_include(:name)
    _(club_columns).must_include(:short_name)
    _(club_columns).must_include(:league_id)
    _(club_columns).must_include(:budget)

    player_columns = Gaffer::Database.db[:players].columns
    _(player_columns).must_include(:position)
    _(player_columns).must_include(:club_id)
    _(player_columns).must_include(:goalkeeping)

    fixture_columns = Gaffer::Database.db[:fixtures].columns
    _(fixture_columns).must_include(:home_club_id)
    _(fixture_columns).must_include(:away_club_id)
    _(fixture_columns).must_include(:played)

    match_columns = Gaffer::Database.db[:matches].columns
    _(match_columns).must_include(:fixture_id)
    _(match_columns).must_include(:home_score)
    _(match_columns).must_include(:events)
    _(match_columns).must_include(:player_ratings)
    _(match_columns).must_include(:narrative)
  end
end
