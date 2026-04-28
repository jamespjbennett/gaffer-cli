# frozen_string_literal: true

module Gaffer
  module Domain
    POSITIONS = %i[gk def mid att].freeze
    MORALE_LEVELS = %i[unhappy unsettled okay happy ecstatic].freeze

    Player = Struct.new(
      :id,
      :name,
      :age,
      :nationality,
      :position,
      :club_id,
      :pace,
      :shooting,
      :passing,
      :dribbling,
      :defending,
      :physical,
      :goalkeeping,
      :overall,
      :potential,
      :form,
      :morale,
      :contract_years,
      :wage,
      keyword_init: true
    )
  end
end
