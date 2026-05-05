# frozen_string_literal: true

require_relative "../test_helper"
require "pastel"
require "stringio"
require "gaffer/domain/club"
require "gaffer/domain/lineup"
require "gaffer/domain/player"
require "gaffer/ui/dugout_lineup"
require "gaffer/ui/dugout_lineup_adjust"
require "gaffer/ui/dugout_lineup_paint"
require "gaffer/presenters/scout_briefing_tty"

describe "DugoutLineupAdjust scout replay" do
  class PickSeq
    attr_reader :last_menu

    def initialize(seq)
      @seq = seq
    end

    def select(_title, rows, **)
      @last_menu = rows
      @seq.shift
    end
  end

  def mk_pl(id, pos, name)
    Gaffer::Domain::Player.new(
      id: id, name: name, age: 22, nationality: "T", position: pos, club_id: 1,
      pace: 60, shooting: 60, passing: 60, dribbling: 60, defending: 60,
      physical: 60, goalkeeping: pos == :gk ? 65 : 5, overall: 60, potential: 65, form: 5, morale: :okay,
      contract_years: 2, wage: 5
    )
  end

  def mk_xi
    Gaffer::Domain::Lineup::FORMATION_SLOTS.each_with_index.map do |pos, i|
      mk_pl(i + 1, pos, "P#{i + 1}")
    end
  end

  def mk_club
    Gaffer::Domain::Club.new(
      id: 1, name: "Us FC", short_name: "US", league_id: 1, reputation: 50, budget: 0, wage_budget: 0,
      stadium: "", chairman_name: "", chairman_mood: :satisfied, board_target: :mid_table
    )
  end

  def mk_sheet(io, scout:, coaching: nil)
    pastel = Pastel.new(enabled: false)
    Gaffer::Ui::DugoutLineup::Sheet.new(
      io,
      pastel,
      mk_club,
      9,
      "OPP",
      true,
      scout,
      coaching
    )
  end

  it "replays scout briefing then repaints dugout when View scout notes chosen" do
    trail = []
    orig_r = Gaffer::Presenters::ScoutBriefingTty.method(:replay_dugout)
    orig_p = Gaffer::Ui::DugoutLineupPaint.method(:paint_opening)
    verb = $VERBOSE
    $VERBOSE = nil
    begin
      Gaffer::Presenters::ScoutBriefingTty.singleton_class.define_method(:replay_dugout) { |*, **| trail << :replay }
      Gaffer::Ui::DugoutLineupPaint.singleton_class.define_method(:paint_opening) { |*, **| trail << :paint_opening }

      squad = mk_xi
      xi = squad.dup
      io = StringIO.new
      sheet = mk_sheet(io, scout: Object.new)
      pr = PickSeq.new(%i[view_scout done])

      Gaffer::Ui::DugoutLineupAdjust.run_loop(sheet, squad, xi, pr)

      _(trail).must_equal %i[replay paint_opening]
    ensure
      Gaffer::Presenters::ScoutBriefingTty.singleton_class.define_method(:replay_dugout, orig_r)
      Gaffer::Ui::DugoutLineupPaint.singleton_class.define_method(:paint_opening, orig_p)
      $VERBOSE = verb
    end
  end

  it "menu includes view row when scout dossier present" do
    xi = mk_xi
    rows = Gaffer::Ui::DugoutLineupAdjust.menu_rows(xi, Object.new)
    first = rows.first
    _(first[:value]).must_equal :view_scout
  end

  it "menu omits view row when scout nil" do
    xi = mk_xi
    rows = Gaffer::Ui::DugoutLineupAdjust.menu_rows(xi, nil)
    _(rows.map { |r| r[:value] }).wont_include(:view_scout)
  end
end
