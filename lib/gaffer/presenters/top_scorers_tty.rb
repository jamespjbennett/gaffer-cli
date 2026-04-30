# frozen_string_literal: true

require "tty-table"

module Gaffer
  module Presenters
    # Season goal chart (Pos · Name · Club · Goals).
    module TopScorersTty
      HEADER = ["Pos", "Name", "Club", "Goals"].freeze

      module_function

      # @param rows [Array<Hash>] keys :pos, :name, :club, :goals, :player_club_id
      # @return [String]
      def render(pastel:, rows:, managed_club_id: nil)
        return pastel.dim("(No goals recorded this season yet.)") if rows.nil? || rows.empty?

        mid = managed_club_id&.to_i
        header_cells = HEADER.map { |label| pastel.bold.white(label.to_s) }

        data_rows =
          rows.map do |r|
            base = [r[:pos], r[:name], r[:club], r[:goals]]
            if mid.positive? && r[:player_club_id].to_i == mid
              base.map { |cell| pastel.bold.cyan(cell.to_s) }
            else
              base.map(&:to_s)
            end
          end

        TTY::Table.new(header: header_cells, rows: data_rows).render(:unicode, multiline: true)
      end
    end
  end
end
