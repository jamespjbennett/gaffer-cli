# frozen_string_literal: true

require_relative "../presenters/matchday_squad"
require_relative "../presenters/scout_digest"

module Gaffer
  module Ui
    # Heading + scout digest + full roster XI render ([`DugoutLineup`] delegates here).
    module DugoutLineupPaint
      module_function

      def paint_opening(sheet, squad, xi)
        heading(sheet)
        scout_digest_maybe(sheet)
        roster_body(sheet, squad, xi)
      end

      def refresh_locked(sheet, xi)
        sheet.out.print("\e[2J\e[H")
        Presenters::MatchdaySquad.print_heading(**heading_args(sheet))
        scout_digest_maybe(sheet)
        locked_tail(sheet, xi)
      end

      def heading_args(s)
        {
          out: s.out,
          pastel: s.pastel,
          club: s.club,
          gameweek: s.gameweek,
          opponent: s.opponent,
          hosting: s.hosting
        }
      end

      def heading(sheet)
        Presenters::MatchdaySquad.print_heading(**heading_args(sheet))
      end

      def scout_digest_maybe(sheet)
        return unless sheet.scout

        Presenters::ScoutDigest.render(sheet.scout, pastel: sheet.pastel, out: sheet.out)
      end

      def roster_body(sheet, squad, xi)
        o = sheet.out
        p = sheet.pastel
        Presenters::MatchdaySquad.print_roster_note(out: o, pastel: p)
        Presenters::MatchdaySquad.print_full_squad_table(out: o, pastel: p, players: squad)
        Presenters::MatchdaySquad.print_xi_heading(out: o, pastel: p)
        Presenters::MatchdaySquad.print_xi_lines(out: o, pastel: p, xi: xi)
      end

      def locked_tail(sheet, xi)
        o = sheet.out
        p = sheet.pastel
        o.puts p.dim("Squad list hidden — XI locked.")
        Presenters::MatchdaySquad.print_xi_heading(out: o, pastel: p)
        Presenters::MatchdaySquad.print_xi_lines(out: o, pastel: p, xi: xi)
      end
    end
  end
end
