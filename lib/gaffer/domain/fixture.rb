# frozen_string_literal: true

module Gaffer
  module Domain
    Fixture = Struct.new(
      :id,
      :season_id,
      :gameweek,
      :home_club_id,
      :away_club_id,
      :played,
      keyword_init: true
    ) do
      def played?
        !!played
      end
    end
  end
end
