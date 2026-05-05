# frozen_string_literal: true

module Gaffer
  module Presenters
    # Compact at-a-glance stats before narrative scout copy (`ScoutBriefing`).
    module ScoutReportTty
      LABEL_WIDTH = 18

      module_function

      # @param report [Domain::ScoutReport]
      def render(report, pastel:, out: $stdout)
        header(report, pastel, out)
        league_position_line(report, pastel, out)
        form_line(report, pastel, out)
        ratings_line(report, out)
        top_scorer_line(report, pastel, out)
        out.puts
        out.puts pastel.dim("─" * 56)
        out.puts
      end

      def header(report, pastel, out)
        opp = report.opponent.name.to_s.strip
        opp = "Opposition" if opp.empty?
        out.puts pastel.dim("┄┄ ") + pastel.bold.white("Scouting: #{opp}") + pastel.dim(" ┄┄")
        out.puts
      end

      def league_position_line(report, pastel, out)
        pos = ordinal(Integer(report.league_position))
        sz = Integer(report.league_size)
        pld = Integer(report.played)
        out.puts "  #{lbl('League position')}#{pos} of #{sz}  #{pastel.dim("(#{pld} played)")}"
      end

      def form_line(report, pastel, out)
        played = Integer(report.played)
        form = Array(report.recent_form)
        if played <= 0 || form.empty?
          out.puts "  #{lbl('Recent form')}#{pastel.dim('No results yet')}"
          return
        end

        w = form.count { |x| x == :w }
        d = form.count { |x| x == :d }
        l_ct = form.count { |x| x == :l }
        glyphs = form.map { |x| form_glyph(x, pastel) }.join(" ")
        suffix = pastel.dim("(W#{w} D#{d} L#{l_ct} last #{form.size})")
        out.puts "  #{lbl('Recent form')}#{glyphs}  #{suffix}"
      end

      def form_glyph(sym, pastel)
        case sym&.to_sym
        when :w then pastel.green("✓")
        when :d then pastel.dim("—")
        when :l then pastel.red("✗")
        else pastel.dim("?")
        end
      end

      def ratings_line(report, out)
        atk = report.attack_rating.to_f
        defn = report.defence_rating.to_f
        out.puts "  #{lbl('Attack')}#{format('%4.1f', atk)}   #{lbl('Defence')}#{format('%4.1f', defn)}"
      end

      def top_scorer_line(report, pastel, out)
        ts = report.top_scorer
        ply = ts&.dig(:player)
        if ply && ply.name.to_s.strip != ""
          g = ts[:goals].to_i
          goal_word = g == 1 ? "goal" : "goals"
          out.puts "  #{lbl('Top scorer')}#{ply.name} · #{g} #{goal_word}"
        else
          out.puts "  #{lbl('Top scorer')}#{pastel.dim('None yet')}"
        end
      end

      def lbl(name)
        name.to_s.ljust(LABEL_WIDTH)
      end

      def ordinal(n)
        n = Integer(n)
        suffix =
          case n % 100
          when 11, 12, 13 then "th"
          else
            case n % 10
            when 1 then "st"
            when 2 then "nd"
            when 3 then "rd"
            else "th"
            end
          end
        "#{n}#{suffix}"
      end
    end
  end
end
