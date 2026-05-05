# frozen_string_literal: true

require_relative "scout_report_tty"

module Gaffer
  module Presenters
    # Stripped dossier pinned above dugout roster (see [`Ui::DugoutLineup`]).
    module ScoutDigest
      WIDTH = 56

      module_function

      def render(report, pastel:, out: $stdout)
        return unless report

        opponent_line(report, pastel, out)
        form_rating_line(report, pastel, out)
        watch_line(report, pastel, out)
        rule(out, pastel)
      end

      def rule(out, pastel)
        out.puts pastel.dim("─" * WIDTH)
        out.puts
      end

      def opponent_line(report, pastel, out)
        line = scout_header_text(report)
        out.puts pastel.dim("── Scout · ") + pastel.bold.white(line)
      end

      def scout_header_text(report)
        nm = opponent_nm(report)
        pos = ScoutReportTty.ordinal(Integer(report.league_position))
        "#{nm} · #{pos} of #{Integer(report.league_size)} (#{Integer(report.played)} played)"
      end

      def opponent_nm(report)
        n = report.opponent.name.to_s.strip
        n.empty? ? "Opposition" : n
      end

      def form_rating_line(report, pastel, out)
        atk, df = rating_pair(report)
        out.puts form_rating_string(report, pastel, atk, df)
      end

      def form_rating_string(report, pastel, atk, df)
        g = form_glyphs(report, pastel)
        tail = pastel.dim("(#{form_record_tail(report)})")
        "  Form #{g}  #{tail}   Atk #{atk}   Def #{df}"
      end

      def rating_pair(report)
        a = format("%4.1f", report.attack_rating.to_f)
        d = format("%4.1f", report.defence_rating.to_f)
        [a, d]
      end

      def form_glyphs(report, pastel)
        arr = Array(report.recent_form)
        return pastel.dim("—") if arr.empty?

        arr.map { |sym| ScoutReportTty.form_glyph(sym, pastel) }.join(" ")
      end

      def form_record_tail(report)
        f = Array(report.recent_form)
        return "no results yet" if f.empty?

        tri = [f.count { |x| x == :w }, f.count { |x| x == :d }, f.count { |x| x == :l }]
        "W#{tri[0]} D#{tri[1]} L#{tri[2]} last #{f.size}"
      end

      def watch_line(report, pastel, out)
        out.puts pastel.white("  #{watch_sentence(report)}")
      end

      def watch_sentence(report)
        wf = report.watch_focus
        return scorer_sentence(report.top_scorer) if wf.nil?

        watch_from_focus(wf, report.top_scorer)
      end

      def watch_from_focus(wf, fallback_ts)
        ply = wf[:player]
        nm = player_nm(ply)
        return scorer_sentence(fallback_ts) if nm.empty?

        "#{watcher_label(wf[:kind])}#{nm}#{watcher_goals_phrase(wf)}"
      end

      def player_nm(ply)
        return "" unless ply.respond_to?(:name)

        ply.name.to_s.strip
      end

      def watcher_label(kind)
        case kind&.to_sym
        when :scorer then "Watch scorer · "
        when :livewire then "Live wire · "
        when :enforcer then "Enforcer · "
        else "Watch · "
        end
      end

      def watcher_goals_phrase(wf)
        g = wf[:goals].to_i
        return "" if g <= 0

        suf = g == 1 ? "goal" : "goals"
        " · #{g} league #{suf}"
      end

      def scorer_sentence(ts)
        ply = ts&.dig(:player)
        nm = player_nm(ply)
        return "Top scorer · none flagged yet." if nm.empty?

        g = ts[:goals].to_i
        word = g == 1 ? "goal" : "goals"
        "Top scorer · #{nm} (#{g} league #{word})"
      end
    end
  end
end
