# frozen_string_literal: true

require_relative "../test_helper"
require "fileutils"
require "pastel"
require "securerandom"
require "stringio"

require "gaffer/database"
require "gaffer"
require "gaffer/commands/start_league"
require "gaffer/commands/next_fixture"

class FixtureDecliningPrompt
  def yes?(*)
    false
  end
end

describe Gaffer::Commands::NextFixture do
  def insert_club(name:, short:)
    Gaffer::Database.db[:clubs].insert(
      name: name,
      short_name: short.upcase.slice(0, 3),
      reputation: 60
    )
  end

  def seed_team(club_id)
    roster = [["Goalie", :gk]]
    roster += 4.times.map { |i| ["Defender #{i}", :def] }
    roster += 3.times.map { |i| ["Mid #{i}", :mid] }
    roster += 3.times.map { |i| ["Fwd #{i}", :att] }
    roster.each do |nom, slot|
      Gaffer::Database.db[:players].insert(
        name: "#{nom}_#{club_id}",
        age: 24,
        nationality: "Testland",
        position: slot.to_s,
        club_id: club_id,
        pace: 70,
        shooting: 70,
        passing: 70,
        dribbling: 70,
        defending: 70,
        physical: 70,
        goalkeeping: slot == :gk ? 80 : 20,
        overall: 70,
        potential: 75,
        form: 6,
        morale: "okay",
        contract_years: 2,
        wage: 10
      )
    end
  end

  before do
    Gaffer::Database.disconnect if Gaffer::Database.connection
    @tmp_path = File.join(File.dirname(__dir__), "..", "tmp", "gaffer_next_fixture_#{SecureRandom.hex(6)}.sqlite")
    FileUtils.mkdir_p(File.dirname(@tmp_path))
    FileUtils.rm_f(@tmp_path)
    ENV["GAFFER_DB_PATH"] = File.expand_path(@tmp_path)

    Gaffer::Database.connect
    Gaffer::Database.migrate

    @club_ids =
      ["Apple United", "Banana Rangers", "Cherry Vale", "Date Town"].map do |name|
        cid = insert_club(name:, short: name[..2])
        seed_team(cid)
        cid
      end

    Gaffer::Commands::StartLeague.run(pastel: Pastel.new, out: StringIO.new)
    mgr_club_id = Gaffer::Repositories::ClubRepository.all.min_by(&:name).id # Apple United alphabetical
    Gaffer::Database.db[:managers].delete
    Gaffer::Database.db[:managers].insert(display_name: "Test Boss", managed_club_id: mgr_club_id)
    @mgr_club_id = mgr_club_id

    @league = Gaffer::Repositories::LeagueRepository.active
    @max_gw = Gaffer::Repositories::FixtureRepository.max_gameweek(@league.id)
  end

  after do
    Gaffer::Database.disconnect
    ENV.delete("GAFFER_DB_PATH")
    FileUtils.rm_f(@tmp_path)
  end

  it "simulates whole gameweek, persists matches, bumps league gw" do
    before_gw = @league.current_gameweek
    pastel = Pastel.new
    log = StringIO.new
    _(Gaffer::Commands::NextFixture.run(pastel:, out: log, prompt: FixtureDecliningPrompt.new)).must_equal :ok

    refreshed = Gaffer::Repositories::LeagueRepository.find(@league.id)
    _(refreshed.current_gameweek).must_equal before_gw + 1

    _(Gaffer::Repositories::FixtureRepository.unplayed_count(@league.id)).must_equal (@max_gw * (@club_ids.size / 2)) - @club_ids.size / 2
    _(Gaffer::Database.db[:matches].count).must_equal (@club_ids.size / 2)
    _(log.string).must_match(/Gameweek 1/)

    _(refreshed.status).must_equal :active
  end

  it "completes league on final simulated round then offers rollover" do
    prompt = FixtureDecliningPrompt.new
    pastel = Pastel.new

    (@max_gw - 1).times do
      _(Gaffer::Commands::NextFixture.run(pastel:, out: StringIO.new, prompt:)).must_equal :ok
    end

    log = StringIO.new
    _(Gaffer::Commands::NextFixture.run(pastel:, out: log, prompt:)).must_equal :season_completed

    _(log.string).must_match(/Final standings/)
    _(log.string).must_match(/┌/)

    final = Gaffer::Repositories::LeagueRepository.find(@league.id)
    _(final.status).must_equal :complete
    _(Gaffer::Repositories::FixtureRepository.unplayed_count(@league.id)).must_equal 0

    pastel = Pastel.new
    _(Gaffer::Commands::NextFixture.run(pastel:, out: StringIO.new)).must_equal :no_active_league
  end
end
