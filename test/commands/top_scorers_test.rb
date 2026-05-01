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
require "gaffer/commands/top_scorers"

class TopScorersFixtureDecliningPrompt
  def yes?(*)
    false
  end
end

describe Gaffer::Commands::TopScorers do
  def manager_xi_preset
    @manager_xi_preset ||= Gaffer::Domain::Lineup.pick_best_xi(
      Gaffer::Repositories::PlayerRepository.for_club(@mgr_club_id)
    )
  end

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
    @tmp_path = File.join(File.dirname(__dir__), "..", "tmp", "gaffer_top_scorers_#{SecureRandom.hex(6)}.sqlite")
    FileUtils.mkdir_p(File.dirname(@tmp_path))
    FileUtils.rm_f(@tmp_path)
    ENV["GAFFER_DB_PATH"] = File.expand_path(@tmp_path)

    Gaffer::Database.prepare

    @club_ids =
      ["Apple United", "Banana Rangers", "Cherry Vale", "Date Town"].map do |name|
        cid = insert_club(name:, short: name[..2])
        seed_team(cid)
        cid
      end

    Gaffer::Commands::StartLeague.run(pastel: Pastel.new, out: StringIO.new)
    mgr_club_id = Gaffer::Repositories::ClubRepository.all.min_by(&:name).id
    Gaffer::Database.db[:managers].delete
    Gaffer::Database.db[:managers].insert(display_name: "Test Boss", managed_club_id: mgr_club_id)
    @mgr_club_id = mgr_club_id

    @league = Gaffer::Repositories::LeagueRepository.active
  end

  after do
    Gaffer::Database.disconnect
    ENV.delete("GAFFER_DB_PATH")
    FileUtils.rm_f(@tmp_path)
  end

  it "lists totals non-empty and descending by goals after a played gameweek with goals" do
    Gaffer::Commands::NextFixture.run(
      pastel: Pastel.new,
      out: StringIO.new,
      prompt: TopScorersFixtureDecliningPrompt.new,
      manager_lineup: manager_xi_preset
    )

    totals = Gaffer::Repositories::GoalEventRepository.totals_by_player(@league.id)
    sum_scores = Gaffer::Database.db[:matches].all.sum do |row|
      row[:home_score].to_i + row[:away_score].to_i
    end
    skip "all scoreless this run — Poisson rolled zero" if sum_scores.zero?

    _(totals).wont_be_empty
    ordered =
      totals.each_cons(2).all? do |a, b|
        b[:goals] < a[:goals] ||
          (b[:goals] == a[:goals] && b[:player_id] >= a[:player_id])
      end
    _(ordered).must_equal true

    log = StringIO.new
    _(Gaffer::Commands::TopScorers.run(pastel: Pastel.new, out: log, league: @league)).must_equal :ok
    _(log.string).must_match(/top scorers/)
    _(log.string).must_match(/┌/)
  end
end
