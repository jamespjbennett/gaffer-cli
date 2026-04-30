# frozen_string_literal: true

module Gaffer
  module Domain
    GoalEvent = Data.define(:id, :fixture_id, :player_id, :club_id, :side)
  end
end
