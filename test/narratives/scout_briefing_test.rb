# frozen_string_literal: true

require_relative "../test_helper"

require "gaffer/domain/club"
require "gaffer/domain/scout_report"
require "gaffer/narratives/scout_briefing"

describe Gaffer::Narratives::ScoutBriefing do
  def minimal_report(**overrides)
    o = overrides[:opp] ||
        Gaffer::Domain::Club.new(
          id: 2,
          name: "Test Town",
          short_name: "TST",
          league_id: nil,
          reputation: 65,
          budget: 1,
          wage_budget: 1,
          stadium: "A",
          chairman_name: "X",
          chairman_mood: :okay,
          board_target: :mid_table
        )
    m = overrides[:mgr] ||
        Gaffer::Domain::Club.new(
          id: 1,
          name: "United FC",
          short_name: "UFC",
          league_id: nil,
          reputation: 60,
          budget: 1,
          wage_budget: 1,
          stadium: "B",
          chairman_name: "Y",
          chairman_mood: :okay,
          board_target: :mid_table
        )
    wf =
      overrides[:watch] ||
      { player: Gaffer::Domain::Player.new(
          id: 9,
          name: "Taylor Vale",
          position: :mid,
          age: 26,
          nationality: "SCO",
          club_id: o.id,
          pace: 78,
          shooting: 70,
          passing: 80,
          dribbling: 74,
          defending: 60,
          physical: 72,
          goalkeeping: 14,
          overall: 75,
          potential: 80,
          form: 7,
          morale: :okay,
          contract_years: 3,
          wage: 40
      ), kind: :livewire, goals: nil }

    Gaffer::Domain::ScoutReport.new(
      opponent: o,
      managed_club: m,
      gameweek: overrides.fetch(:gameweek, 3),
      hosting_managed: overrides.fetch(:hosting_managed, false),
      league_position: overrides.fetch(:league_position, 5),
      league_size: overrides.fetch(:league_size, 10),
      played: overrides.fetch(:played, 4),
      manager_league_position: overrides.fetch(:manager_league_position, 7),
      manager_played: overrides.fetch(:manager_played, 4),
      manager_points: overrides.fetch(:manager_points, 8),
      opponent_points: overrides.fetch(:opponent_points, 11),
      recent_form: overrides.fetch(:recent_form, %i[w l d w l]),
      attack_rating: overrides.fetch(:attack_rating, 62.4),
      defence_rating: overrides.fetch(:defence_rating, 54.1),
      our_attack_rating: overrides.fetch(:our_attack_rating, 58.0),
      our_defence_rating: overrides.fetch(:our_defence_rating, 56.2),
      top_scorer: overrides.fetch(:top_scorer, nil),
      watch_focus: wf
    )
  end

  it "returns conversational paragraphs tying together table, tone, and a watch name" do
    lines = Gaffer::Narratives::ScoutBriefing.paragraphs(minimal_report)
    blob = lines.join(" ")
    _(blob).must_match(/Gameweek 3/)
    _(blob).must_match(/Taylor Vale/)
    _(blob).must_match(/Test Town/)
    _(blob).must_match(/win/)
    _(lines.size).must_be :>=, 5
  end

  it "mentions early-season tone before the league wakes up" do
    lines = Gaffer::Narratives::ScoutBriefing.paragraphs(minimal_report(played: 0, manager_played: 0, recent_form: [], opponent_points: 0, manager_points: 0))
    _(lines.join).must_match(/early doors|let's get stuck in/i)
  end
end
