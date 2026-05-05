# frozen_string_literal: true

require_relative "../test_helper"
require "gaffer/domain/player"
require "gaffer/domain/club"
require "gaffer/domain/coaching_context"
require "gaffer/narratives/coach_training_report"
require "gaffer/narratives/coach_training_matrix"

describe "Gaffer::Narratives::CoachTrainingReport" do
  let(:club) { Gaffer::Domain::Club.new(name: "T", short_name: "TST", league_id: 1, reputation: 50) }

  def pl(form:, morale: :okay, name: "Pat")
    Gaffer::Domain::Player.new(
      name: name,
      age: 22,
      nationality: "X",
      position: :mid,
      club_id: 1,
      pace: 70,
      shooting: 70,
      passing: 70,
      dribbling: 70,
      defending: 70,
      physical: 70,
      goalkeeping: 20,
      overall: 70,
      potential: 75,
      form: form,
      morale: morale,
      contract_years: 2,
      wage: 5
    )
  end

  it "steady copy when nobody stands out from neutral" do
    ctx = Gaffer::Domain::CoachingContext.new(managed_club: club, rising: [], falling: [])
    lines = Gaffer::Narratives::CoachTrainingReport.paragraphs(ctx)
    _(lines.first).must_equal Gaffer::Narratives::CoachTrainingReport::STEADY
  end

  it "steady when coaching context omitted" do
    _(Gaffer::Narratives::CoachTrainingReport.paragraphs(nil).size).must_equal 1
  end

  it "includes rising and falling labels with sentences" do
    ctx =
      Gaffer::Domain::CoachingContext.new(
        managed_club: club,
        rising: [pl(form: 10, morale: :happy, name: "UpPat")],
        falling: [pl(form: 1, morale: :unhappy, name: "DownPat")]
      )
    lines = Gaffer::Narratives::CoachTrainingReport.paragraphs(ctx)
    _(lines.any?(/Training notes · TST/)).must_equal true
    _(lines).must_include("Sharp in training:")
    _(lines.any?(/UpPat/)).must_equal true
    _(lines).must_include("Concern:")
    _(lines.any?(/DownPat/)).must_equal true
  end
end

describe "Gaffer::Narratives::CoachTrainingMatrix" do
  it "fills unhappy-low-form cliché from matrix" do
    p =
      Gaffer::Domain::Player.new(
        name: "Ron",
        age: 21,
        nationality: "ZZ",
        position: :gk,
        club_id: 1,
        pace: 50,
        shooting: 40,
        passing: 50,
        dribbling: 50,
        defending: 50,
        physical: 60,
        goalkeeping: 70,
        overall: 60,
        potential: 70,
        form: 2,
        morale: :unhappy,
        contract_years: 1,
        wage: 1
      )
    s = Gaffer::Narratives::CoachTrainingMatrix.sentence(p)
    _(s).must_match(/^Ron/)

    _(s.downcase).must_match(/well off it|miles from his best/)
  end

  it "maps ecstatic + peak form" do
    p =
      Gaffer::Domain::Player.new(
        name: "Ace",
        age: 21,
        nationality: "ZZ",
        position: :att,
        club_id: 1,
        pace: 80,
        shooting: 85,
        passing: 80,
        dribbling: 82,
        defending: 50,
        physical: 80,
        goalkeeping: 12,
        overall: 80,
        potential: 90,
        form: 10,
        morale: :ecstatic,
        contract_years: 3,
        wage: 5
      )
    _(Gaffer::Narratives::CoachTrainingMatrix.sentence(p).downcase).must_match(/running the show|handful|flying|top form/)
  end

  it "worried band ignores ecstatic morale — form-only slump copy" do
    p =
      Gaffer::Domain::Player.new(
        name: "Jamie",
        age: 24,
        nationality: "ENG",
        position: :mid,
        club_id: 1,
        pace: 70,
        shooting: 70,
        passing: 70,
        dribbling: 70,
        defending: 70,
        physical: 70,
        goalkeeping: 20,
        overall: 70,
        potential: 75,
        form: 4,
        morale: :ecstatic,
        contract_years: 2,
        wage: 5
      )
    w = Gaffer::Narratives::CoachTrainingMatrix.sentence_for_band(p, :falling)
    _(w.downcase).wont_include("purring")
    _(w.downcase).wont_include("opens the defence")
    _(w).must_include("Jamie")
  end

  it "worried GK uses keeper-focused phrasing" do
    p =
      Gaffer::Domain::Player.new(
        name: "Jules",
        age: 22,
        nationality: "SCO",
        position: :gk,
        club_id: 1,
        pace: 50,
        shooting: 40,
        passing: 55,
        dribbling: 40,
        defending: 50,
        physical: 70,
        goalkeeping: 78,
        overall: 65,
        potential: 72,
        form: 4,
        morale: :ecstatic,
        contract_years: 3,
        wage: 4
      )
    w = Gaffer::Narratives::CoachTrainingMatrix.sentence_for_band(p, :falling).downcase
    _(w).must_match(/crosses|kicking|commanding|organising|ball at his feet/)
    _(w).wont_include("corridor")
  end
end
