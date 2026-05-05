# frozen_string_literal: true

require "tty-table"

module Gaffer
  module Presenters
    # Pre-match dugout sheet: full roster + morale / soft "load" hints (persistent injuries not in DB yet).
    module MatchdaySquad
      POS_ORDER = { gk: 0, def: 1, mid: 2, att: 3 }.freeze

      FOOTNOTE = "Injuries not yet tracked. Mood shown as a guide — Risk column reflects morale only."

      module_function

      # @param hosting [Boolean] managed club hosting
      def print_heading(out:, pastel:, club:, gameweek:, opponent:, hosting:)
        ha = hosting ? pastel.green("Hosting") : pastel.blue("Away")
        out.puts
        out.puts "#{pastel.bold.white("Gameweek #{gameweek}")}  #{pastel.dim("#{ha} · #{club.name}")}"
        out.puts "#{pastel.dim("Opposition:")} #{pastel.bold(opponent)}"
      end

      def print_roster_note(out:, pastel:)
        out.puts pastel.dim(FOOTNOTE)
      end

      # @param players [Array<Domain::Player>]
      def print_full_squad_table(out:, pastel:, players:)
        rows =
          sorted_for_display(players).map do |p|
            pos = p.position.to_s.upcase.ljust(3)
            morale = morale_short(p.respond_to?(:morale) ? p.morale : nil)
            [
              pastel.dim(pos),
              p.name.to_s.slice(0, 22),
              p.overall.to_s.rjust(2),
              "#{p.respond_to?(:form) ? (p.form || "—").to_s : '—'} /10",
              morale,
              p.physical.to_s.rjust(2),
              key_attrs_for(p),
              knack_note(p.respond_to?(:morale) ? p.morale : nil)
            ]
          end

        table = TTY::Table.new(
          header: [
            pastel.bold("Lin"),
            pastel.bold("Player"),
            pastel.bold("Ovr"),
            pastel.bold("Form"),
            pastel.bold("Mood"),
            pastel.bold("Phy"),
            pastel.bold("Attrs"),
            pastel.bold("Risk")
          ],
          rows: rows
        )

        out.puts table.render(:unicode, padding: [0, 1], multiline: true)
      end

      def print_xi_heading(out:, pastel:)
        out.puts
        out.puts pastel.bold.white("Your starting XI · 4-3-3")
      end

      # @param xi [Array<Domain::Player>]
      def print_xi_lines(out:, pastel:, xi:)
        xi.each_with_index do |p, i|
          lab = Domain::Lineup::XI_SLOT_LABELS[i]
          out.puts "  #{pastel.bold(lab.ljust(3))}  #{p.name}  #{pastel.dim("OVR #{p.overall} · F #{p.form} · #{morale_short(p.morale)} · #{knack_note(p.morale)}")}"
        end
      end

      def sorted_for_display(players)
        players.sort_by do |p|
          pos_ord = POS_ORDER.fetch(p.respond_to?(:position) ? p.position&.to_sym : nil, 99)
          [pos_ord, -Domain::Lineup.grade_scalar(p)]
        end
      end

      def key_attrs_for(p)
        unless Domain::Player === p && p.respond_to?(:position)
          return "---"
        end

        case p.position&.to_sym
        when :gk
          "Gk#{dash(p.goalkeeping)} Ph#{dash(p.physical)}"
        when :def
          "Df#{dash(p.defending)} Pc#{dash(p.pace)}"
        when :mid
          "Ps#{dash(p.passing)} Dr#{dash(p.dribbling)}"
        when :att
          "Sh#{dash(p.shooting)} Pc#{dash(p.pace)}"
        else
          "---"
        end
      end

      def dash(v)
        v.nil? ? "—" : v.to_s
      end
      private_class_method :dash

      def morale_short(sym)
        case sym&.to_sym
        when nil then "---"
        when :okay then "OK"
        when :happy then "Hap"
        when :delighted then "Del"
        when :unsettled then "Uns"
        when :ecstatic then "Ecs"
        when :unhappy then "Unh"
        when :concerned then "Con"
        when :satisfied then "Sat"
        when :furious then "Fur"
        else sym.to_s[..3]
        end
      end

      def knack_note(morale)
        case morale&.to_sym
        when :unhappy then "High"
        when :unsettled then "Med"
        else "Low"
        end
      end
    end
  end
end
