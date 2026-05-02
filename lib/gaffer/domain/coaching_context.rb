# frozen_string_literal: true

require_relative "club"
require_relative "player"

module Gaffer
  module Domain
    # Snapshot for templated coach copy — notable squad moods before the next XI pick.
    CoachingContext = Data.define(:managed_club, :rising, :falling) do
      def notable?
        rising.any? || falling.any?
      end
    end
  end
end
