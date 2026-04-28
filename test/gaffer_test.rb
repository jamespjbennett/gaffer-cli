# frozen_string_literal: true

require_relative "test_helper"
require "gaffer"

describe Gaffer do
  it "exposes a version" do
    _(Gaffer::VERSION).must_match(/\A\d+\.\d+\.\d+/)
  end
end
