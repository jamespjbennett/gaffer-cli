# frozen_string_literal: true

module Gaffer
  module Domain
    module Morale
      module FormNorm
        module_function

        def clamped(player)
          raw = player.form
          return 5 if raw.nil?
          raw.to_i.clamp(1, 10)
        end

        def soft_merge_to_five(form)
          f = form.nil? ? 5 : form.to_i.clamp(1, 10)
          (f + 5) / 2
        end
      end
    end
  end
end
