# frozen_string_literal: true

module Gaffer
  module Domain
    # Row in `leagues` — one league row *is* a season (year, status, current gameweek).
    LEAGUE_STATUSES = %i[pending active complete].freeze

    League = Struct.new(:id, :name, :year, :status, :current_gameweek, keyword_init: true) do
      def active?
        status&.to_sym == :active
      end

      def complete?
        status&.to_sym == :complete
      end
    end
  end
end
