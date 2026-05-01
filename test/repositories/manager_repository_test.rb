# frozen_string_literal: true

require_relative "../test_helper"
require "fileutils"
require "securerandom"
require "gaffer/database"
require "gaffer"
require "gaffer/domain/manager"

describe Gaffer::Repositories::ManagerRepository do
  before do
    Gaffer::Database.disconnect if Gaffer::Database.connection
    @tmp_path = File.join(Dir.tmpdir, "gaffer_manager_test_#{SecureRandom.hex(6)}.sqlite")
    FileUtils.rm_f(@tmp_path)
    ENV["GAFFER_DB_PATH"] = @tmp_path
    Gaffer::Database.prepare
    @club_id = Gaffer::Database.db[:clubs].insert(
      name: "Testville",
      short_name: "TST",
      reputation: 62,
      budget: 10,
      wage_budget: 5,
      stadium: "Test Park",
      chairman_name: "Chair",
      chairman_mood: "okay",
      board_target: "mid_table"
    )
  end

  after do
    Gaffer::Database.disconnect
    ENV.delete("GAFFER_DB_PATH")
    FileUtils.rm_f(@tmp_path) if defined?(@tmp_path) && @tmp_path
  end

  it "starts with no manager" do
    _(Gaffer::Repositories::ManagerRepository.current).must_be_nil
    _(Gaffer::Repositories::ManagerRepository.needs_onboarding?).must_equal true
  end

  it "activates a singleton manager profile" do
    saved = Gaffer::Repositories::ManagerRepository.activate!(
      display_name: "  Pat Test  ",
      managed_club_id: @club_id
    )
    _(saved.display_name).must_equal "Pat Test"
    _(saved.managed_club_id).must_equal @club_id

    again = Gaffer::Repositories::ManagerRepository.current
    _(again.display_name).must_equal "Pat Test"
    _(Gaffer::Repositories::ManagerRepository.needs_onboarding?).must_equal false
  end

  it "replacing activation keeps a single row" do
    Gaffer::Repositories::ManagerRepository.activate!(display_name: "A", managed_club_id: @club_id)
    Gaffer::Repositories::ManagerRepository.activate!(display_name: "B", managed_club_id: @club_id)

    _(Gaffer::Database.db[:managers].count).must_equal 1
    _(Gaffer::Repositories::ManagerRepository.current.display_name).must_equal "B"
  end

  it "rejects blank display_name" do
    _(proc do
      Gaffer::Repositories::ManagerRepository.activate!(display_name: "   ", managed_club_id: @club_id)
    end).must_raise ArgumentError
  end
end
