# frozen_string_literal: true

module Gaffer
  module Presenters
    # Lightweight table rendering until full `tty-table` (Step 6).
    module LeagueTableView
      module_function

      # Top three plus managed club with ellipsis when outside top three.
      def print_snippet(out:, pastel:, rows:, positions_by_club:, managed_club_id:)
        return unless rows&.any?

        mid = managed_club_id&.to_i
        out.puts pastel.bold.white("Standings snapshot")
        out.puts pastel.dim("(top 3 and your club)")

        top = rows.take(3)
        print_rows(out:, pastel:, rows: top, positions_by_club:, managed_club_id: mid)

        pos = mid ? positions_by_club[mid] : nil
        return if pos.nil? || pos <= 3

        out.puts pastel.dim("  #{mid ? '…' : '—'}")
        row = rows.find { |r| r.club.id.to_i == mid }
        print_rows(out:, pastel:, rows: [row], positions_by_club:, managed_club_id: mid) if row

        nil
      end

      # Full standings (e.g. end of season).
      # @param heading [Boolean] when false, skip the "Standings" banner (caller printed a custom title).
      def print_full(out:, pastel:, rows:, positions_by_club:, managed_club_id: nil, heading: true)
        return unless rows&.any?

        out.puts pastel.bold.white("Standings") if heading

        rows.each do |row|
          pos = positions_by_club[row.club.id]
          txt = formatted_line(pos, row)
          emphasis = managed_club_id.to_i.nonzero? && row.club.id.to_i == managed_club_id.to_i

          out.puts(if emphasis && managed_club_id
                     pastel.bold.cyan(txt)
                   else
                     pastel.dim(txt)
                   end)
        end
        nil
      end

      def formatted_line(position, row)
        sprintf(
          "  %2d  %-24s  %2d played  %d-%d-%d  %4d gf  %4d ga  %4d gd  %3d pts",
          position,
          truncate_club(row.club.name),
          row.played,
          row.won,
          row.drawn,
          row.lost,
          row.gf,
          row.ga,
          row.gd,
          row.points
        )
      end

      def truncate_club(name, max = 24)
        s = name.to_s
        s.length <= max ? s : "#{s.slice(0, max - 1)}…"
      end

      def print_rows(out:, pastel:, rows:, positions_by_club:, managed_club_id: nil)
        rows.each do |row|
          pos = positions_by_club[row.club.id]
          txt = formatted_line(pos, row)
          if managed_club_id && row.club.id.to_i == managed_club_id.to_i
            out.puts pastel.bold.green(txt)
          else
            out.puts pastel.dim(txt)
          end
        end
      end
    end
  end
end
