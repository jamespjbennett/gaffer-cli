# frozen_string_literal: true

module Gaffer
  module Domain
    # Chairman mood and board target map to string columns; use symbols in Ruby.
    CHAIRMAN_MOODS = %i[furious concerned satisfied delighted].freeze
    BOARD_TARGETS = %i[avoid_relegation mid_table top_half europe title].freeze

    Club = Struct.new(
      :id,
      :name,
      :short_name,
      :league_id,
      :reputation,
      :budget,
      :wage_budget,
      :stadium,
      :chairman_name,
      :chairman_mood,
      :board_target,
      keyword_init: true
    )
  end
end
