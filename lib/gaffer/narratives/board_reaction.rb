# frozen_string_literal: true

require_relative "board_reaction/context"
require_relative "board_reaction/tone"
require_relative "board_reaction/wins"
require_relative "board_reaction/draws"
require_relative "board_reaction/losses"
require_relative "board_reaction/picker"

module Gaffer
  module Narratives
    # Rules-based chairman/board line after FT.
    module BoardReaction
      module_function

      def message(ctx)
        Picker.new(ctx).call
      end
    end
  end
end
