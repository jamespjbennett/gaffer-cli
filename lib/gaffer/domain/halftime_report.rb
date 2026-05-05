# frozen_string_literal: true

module Gaffer
  module Domain
    # Packed read model for halftime TTY (`Commands::Support::HalftimeReportBuilder`).
    HalftimeReport = Data.define(
      :snapshot,
      :managed_is_home,
      :managed_label,
      :opponent_label,
      :managed_hot,
      :managed_cold,
      :opponent_hot,
      :opponent_cold,
      :managed_strength_lines,
      :managed_weak_lines,
      :opponent_strength_lines,
      :opponent_weak_lines
    )
  end
end
