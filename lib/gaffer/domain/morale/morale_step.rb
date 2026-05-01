# frozen_string_literal: true

require_relative "../player"

module Gaffer
  module Domain
    module Morale
      module MoraleStep
        LEVELS = Domain::MORALE_LEVELS
        MID_OKAY_IDX = LEVELS.index(:okay)

        module_function

        def apply_shift(moral, delta)
          idx = level_index(moral)
          LEVELS[(idx + delta).clamp(0, LEVELS.size - 1)]
        end

        def toward_okay(moral)
          idx = level_index(moral)
          return moral if idx == MID_OKAY_IDX
          drift_index(idx)
        end

        def level_index(moral)
          LEVELS.index(moral&.to_sym) || MID_OKAY_IDX
        end

        def drift_index(idx)
          step = idx > MID_OKAY_IDX ? -1 : 1
          LEVELS[idx + step]
        end
      end
    end
  end
end
