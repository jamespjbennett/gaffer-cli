# frozen_string_literal: true

require_relative "player"

module Gaffer
  module Domain
    # Per-player morale band + linear form interpolation.
    class MoraleFormMultiplier
      BANDS = {
        unhappy: [0.82, 0.90],
        unsettled: [0.88, 0.96],
        okay: [0.94, 1.03],
        happy: [0.99, 1.08],
        ecstatic: [1.04, 1.14]
      }.freeze

      class << self
        def for(player)
          lo, hi = band_edges(player.morale)
          lo + fraction(player.form) * (hi - lo)
        end

        private

        def band_edges(moral)
          BANDS.fetch(moral&.to_sym, BANDS.fetch(:okay))
        end

        def fraction(raw_form)
          f = raw_form.nil? ? 5 : raw_form.to_i.clamp(1, 10)
          (f - 1) / 9.0
        end
      end
    end
  end
end
