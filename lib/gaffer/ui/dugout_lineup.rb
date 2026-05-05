# frozen_string_literal: true

require_relative "dugout_lineup_paint"
require_relative "dugout_lineup_preset"
require_relative "dugout_lineup_adjust"

module Gaffer
  module Ui
    # Orchestrates dugout XI flow; paint / preset / adjust live in sibling modules.
    module DugoutLineup
      Sheet = Data.define(:out, :pastel, :club, :gameweek, :opponent, :hosting, :scout, :coaching)

      class << self
        def resolve(preset:, suggested_xi:, full_squad:, club:, prompt:, pastel:, out:, gameweek:, opponent:, hosting:,
                    scout: nil, coaching: nil)
          locked = DugoutLineupPreset.validate_lineup(preset, full_squad)
          return locked if locked

          sheet = Sheet.new(out, pastel, club, gameweek, opponent, hosting, scout, coaching)
          xi = suggested_xi.dup
          DugoutLineupPaint.paint_opening(sheet, full_squad, xi)
          return auto_xi(xi, pastel, out) unless prompt&.respond_to?(:yes?)

          return lock_in(sheet, xi) if prompt.yes?(pastel.bold("Start with this XI?"), default: true)

          return keep_suggested(xi, pastel, out) unless prompt.respond_to?(:select)

          DugoutLineupAdjust.run_loop(sheet, full_squad, xi, prompt)
          finalize_locked(sheet, xi)
        end

        private

        def auto_xi(xi, pastel, out)
          out.puts pastel.dim("Non-interactive shell — auto-starting suggested XI.")
          xi
        end

        def keep_suggested(xi, pastel, out)
          out.puts pastel.dim("TTY select unavailable — keeping suggested XI.")
          xi
        end

        def lock_in(sheet, xi)
          DugoutLineupPaint.refresh_locked(sheet, xi)
          xi
        end

        def finalize_locked(sheet, xi)
          DugoutLineupPaint.refresh_locked(sheet, xi)
          xi
        end
      end
    end
  end
end
