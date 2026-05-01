# frozen_string_literal: true

require_relative "../../test_helper"
require "fileutils"
require "pastel"
require "securerandom"
require "stringio"

require "gaffer/database"
require "gaffer"
require "gaffer/commands/start_league"
require "gaffer/commands/next_fixture"
require "gaffer/commands/support/scout_report_builder"

class ScoutReportDecliningPrompt
  def yes?(*)
    false
  end
end

describe Gaffer::Commands::Support::ScoutReportBuilder do
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
    @tmp_path = File.join(File.dirname(__dir__), "..", "..", "tmp", "gaffer_scout_#{SecureRandom.hex(6)}.sqlite")
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
    fx =
      Gaffer::Repositories::FixtureRepository.next_for_club(
        season_id: @league.id,
        club_id: @mgr_club_id
      )
    @opp_club =
      Gaffer::Repositories::ClubRepository.find(
        fx.home_club_id.to_i == @mgr_club_id.to_i ? fx.away_club_id : fx.home_club_id
      )
  end

  after do
    Gaffer::Database.disconnect
    ENV.delete("GAFFER_DB_PATH")
    FileUtils.rm_f(@tmp_path)
  end

  describe ".recent_form_for" do
    it "maps chronological results into last-five W/D/L from the opponent view" do
      rows = [
        { home_club_id: 1, away_club_id: 2, home_score: 2, away_score: 0 },
        { home_club_id: 2, away_club_id: 3, home_score: 1, away_score: 1 },
        { home_club_id: 3, away_club_id: 2, home_score: 0, away_score: 3 }
      ]
      f = Gaffer::Commands::Support::ScoutReportBuilder.recent_form_for(opponent_club_id: 2, chronological_results: rows)
      _(f).must_equal %i[l d w]
    end
  end

  describe ".build" do
    def build_for_opp
      Gaffer::Commands::Support::ScoutReportBuilder.build(
        opponent_club: @opp_club,
        managed_club: Gaffer::Repositories::ClubRepository.find(@mgr_club_id),
        league_id: @league.id,
        gameweek: 1,
        hosting_managed: true
      )
    end

    it "shows no form and no top scorer before any results" do
      r = build_for_opp
      _(r.played).must_equal 0
      _(r.manager_played).must_equal 0
      _(r.recent_form).must_equal []
      _(r.top_scorer).must_be_nil
      _(r.watch_focus).wont_be_nil
      _(r.attack_rating).must_be :>, 0.0
      _(r.defence_rating).must_be :>, 0.0
      _(r.league_position).must_be :>=, 1
      _(r.league_size).must_equal @club_ids.size
      _(r.our_attack_rating).must_be :>, 0.0
      _(Integer(r.gameweek)).must_equal 1
    end

    it "after one gameweek shows one result in form and positive ratings" do
      xi = Gaffer::Domain::Lineup.pick_best_xi(
        Gaffer::Repositories::PlayerRepository.for_club(@mgr_club_id)
      )
      Gaffer::Commands::NextFixture.run(
        pastel: Pastel.new,
        out: StringIO.new,
        prompt: ScoutReportDecliningPrompt.new,
        manager_lineup: xi
      )

      gw2 = Gaffer::Repositories::FixtureRepository.next_for_club(
        season_id: @league.id,
        club_id: @mgr_club_id
      ).gameweek.to_i

      r = Gaffer::Commands::Support::ScoutReportBuilder.build(
        opponent_club: @opp_club,
        managed_club: Gaffer::Repositories::ClubRepository.find(@mgr_club_id),
        league_id: @league.id,
        gameweek: gw2,
        hosting_managed: false
      )

      _(r.played).must_equal 1
      _(r.recent_form.size).must_equal 1
      _(%i[w d l]).must_include r.recent_form.first
      _(r.attack_rating).must_be :>, 0.0
      _(r.defence_rating).must_be :>, 0.0
    end
  end
end
