# frozen_string_literal: true

require_relative "../test_helper"
require "fileutils"
require "pastel"
require "securerandom"
require "stringio"

require "gaffer/database"
require "gaffer"
require "gaffer/commands/start_league"
require "gaffer/commands/league_standings"

describe Gaffer::Commands::LeagueStandings do
  before do
    Gaffer::Database.disconnect if Gaffer::Database.connection
    @tmp_path = File.join(Dir.tmpdir, "gaffer_table_cmd_#{SecureRandom.hex(6)}.sqlite")
    FileUtils.rm_f(@tmp_path)
    ENV["GAFFER_DB_PATH"] = @tmp_path
    Gaffer::Database.prepare

    4.times do |i|
      cid =
        Gaffer::Database.db[:clubs].insert(
          name: "Club #{100 + i}",
          short_name: "C#{i}",
          reputation: 50
        )
      11.times do |pidx|
        Gaffer::Database.db[:players].insert(
          name: "P#{cid}_#{pidx}",
          position: pidx.zero? ? "gk" : "mid",
          club_id: cid,
          pace: 70,
          shooting: 70,
          passing: 70,
          dribbling: 70,
          defending: 70,
          physical: 70,
          goalkeeping: pidx.zero? ? 78 : 20
        )
      end
    end

    _(Gaffer::Commands::StartLeague.run(pastel: Pastel.new, out: StringIO.new)).must_equal :ok
    mgr_id = Gaffer::Repositories::ClubRepository.all.first.id
    Gaffer::Database.db[:managers].delete
    Gaffer::Database.db[:managers].insert(display_name: "Gaffer Bot", managed_club_id: mgr_id)
    @active = Gaffer::Repositories::LeagueRepository.active
    _( @active ).wont_be_nil

    Gaffer::Commands::NextFixture.run(pastel: Pastel.new, out: StringIO.new, prompt: (Class.new do
                                                                                       def yes?(*)
                                                                                         false
                                                                                       end
                                                                                     end).new)
    Gaffer::Database.disconnect

    ENV["GAFFER_DB_PATH"] = @tmp_path
    Gaffer::Database.prepare
  end

  after do
    Gaffer::Database.disconnect
    ENV.delete("GAFFER_DB_PATH")
    FileUtils.rm_f(@tmp_path)
  end

  it "prints a tty unicode table including standard columns and stats" do
    io = StringIO.new

    pastel = Pastel.new
    _(Gaffer::Commands::LeagueStandings.run(pastel:, out: io)).must_equal :ok

    buf = io.string
    _(buf).must_include "Pts"
    _(buf).must_include "Club"
    _(buf).must_match(/┌[─┬]+┐/)
    _(buf).must_include "#{@active.name}"
  end

  it "reports no standings when league finished" do
    Gaffer::Repositories::LeagueRepository.complete!(@active.id)
    pastel = Pastel.new
    io = StringIO.new

    _(Gaffer::Commands::LeagueStandings.run(pastel:, out: io)).must_equal :no_active_league
    _(io.string).must_match(/no active league/i)
  end

  it "shows the latest archived table when --previous" do
    Gaffer::Repositories::LeagueRepository.complete!(@active.id)

    io = StringIO.new
    pastel = Pastel.new
    _(Gaffer::Commands::LeagueStandings.run(pastel:, out: io, previous: true)).must_equal :ok

    _(io.string.downcase).must_include "archived"
    _(io.string).must_match(/┌[─┬]+┐/)
  end

  it "returns missing when calendar year not on file" do
    pastel = Pastel.new
    io = StringIO.new

    _(Gaffer::Commands::LeagueStandings.run(pastel:, out: io, year: 1900)).must_equal :no_standings_target
    _(io.string).must_match(/No saved league/i)
  end
end
