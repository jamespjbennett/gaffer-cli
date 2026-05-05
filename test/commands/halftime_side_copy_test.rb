# frozen_string_literal: true

require_relative "../test_helper"
require "gaffer/commands/support/halftime_side_copy"

describe Gaffer::Commands::Support::HalftimeSideCopy do
  C = Gaffer::Commands::Support::HalftimeSideCopy

  it "chances copy flips for opponent lens" do
    _(C.chances_big(2, :managed)).must_include "Caused real problems"
    _(C.chances_big(2, :managed)).must_include "created."
    _(C.chances_big(2, :opponent)).must_include "Created real problems for us"
  end

  it "low shots copy names our goal when describing opponent drought" do
    _(C.low_shots(:opponent)).must_include "your keeper"
    _(C.low_shots(:managed)).must_include "their goal"
  end

  it "goals_positive returns nil when zero" do
    _(C.goals_positive({ goals: 0 }, :managed)).must_be_nil
  end

  it "goals copy for opponent references you" do
    g = C.goals_positive({ goals: 2 }, :opponent)
    _(g).must_include "against you"
  end
end
