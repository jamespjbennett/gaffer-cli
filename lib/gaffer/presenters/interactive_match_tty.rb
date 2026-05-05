# frozen_string_literal: true

module Gaffer
  module Presenters
    # Minute-clustered commentary rails for league interactive matches.
    module InteractiveMatchTty
      STOPS = [5, 15, 25, 35, 45, 55, 65, 75, 85, 90].freeze

      module_function

      def first_half(runner, snap, pastel:, out:, prompt:)
        wipe(out)
        out.puts pastel.bold.white("#{runner.home_club.name} #{snap.home_score}–#{snap.away_score} #{runner.away_club.name}")

        headline(snap, pastel, out, "FIRST HALF")
        stream(snap.events, pastel, out, upto: 45,
          home_club: runner.home_club, away_club: runner.away_club)
        recap(snap, pastel, out)
        pause(prompt, pastel, out, "Half-time beckons →")
      end

      def halftime_board(report, pastel:, out:, prompt:)
        wipe(out)
        out.puts pastel.bold.white("HALFTIME · #{report.managed_label} vs #{report.opponent_label}")

        tiles(report.snapshot, pastel, out)

        dossier(report, pastel, out)
        pause(prompt, pastel, out, "Back to tunnel →")
      end

      def second_half(snap, runner:, pastel:, out:, prompt:)
        wipe(out)
        headline(snap, pastel, out, "SECOND HALF")
        stream(second_slice(snap.events), pastel, out, upto: 90,
          home_club: runner.home_club, away_club: runner.away_club)
        recap(snap, pastel, out)
        pause(prompt, pastel, out, "Full time looming →")
      end

      def full_time_banner(result, pastel:, out:, prompt: nil)
        out.puts
        out.puts pastel.bold.white("MATCH COMPLETE #{result.home_score}–#{result.away_score}")
        out.puts pastel.dim("(λ #{result.home_xg_lambda.round(2)} / #{result.away_xg_lambda.round(2)})")
        pause(prompt, pastel, out, "Wrap →")
      end

      def second_slice(events)
        events.select { |e| e.minute.to_i > 45 }
      end

      def wipe(out)
        out.print("\e[2J\e[H")
        out.puts
      end

      def headline(snap, pastel, out, tag)
        out.puts pastel.bold.white("#{tag} @ #{snap.minute}'")
        out.puts
      end

      def stream(events, pastel, out, upto:, home_club:, away_club:)
        hi = club_line_label(home_club)
        ai = club_line_label(away_club)
        STOPS.select { |m| m <= upto }.each do |tick|
          chunk = bucket(events, tick)
          out.puts pastel.dim(minute_range_line(tick))
          chunk.each { |evt| spit(evt, pastel, out, hi, ai) }

          out.puts
        end
      end

      def bucket(events, tick)
        events.select { |evt| span?(evt.minute.to_i, tick) }
      end

      def span?(minute, tick)
        minute <= tick && minute > tick - 10
      end

      # Matches #bucket — label the inclusive minute window rolled up at +tick+.
      def minute_range_line(tick)
        lo = [tick - 9, 1].max
        "#{lo}–#{tick}′"
      end

      def club_line_label(club)
        nm = club.name.to_s.strip
        short = club.short_name.to_s.strip
        return nm if short.empty? || short.casecmp(nm).zero?

        "#{nm} (#{short})"
      end

      def spit(evt, pastel, out, home_label, away_label)
        tag = evt.side == :home ? home_label : away_label
        ply = evt.player&.name.to_s.strip
        ply = "?" if ply.empty?
        min = evt.minute.to_i
        rest =
          case evt.type
          when :goal then "Goal — #{ply} · #{min}'"
          when :big_chance then "Big chance missed — #{ply} · #{min}'"
          else evt.description.to_s.strip
          end
        prefix = pastel.dim("#{tag}: ")
        body =
          evt.type == :goal ? pastel.green.bold(rest) : pastel.white(rest)
        out.puts "  #{prefix}#{body}"
      end

      def recap(snap, pastel, out)
        out.puts pastel.bold("Score: #{snap.home_score}–#{snap.away_score} · #{snap.minute} minutes played")
      end

      def pause(prompt, pastel, out, label)
        return prompt.keypress(pastel.dim(label)) if prompt.respond_to?(:keypress)

        out.puts pastel.dim("(auto)")
      end

      def tiles(snap, pastel, out)
        hs = snap.team_stats.fetch(:home)
        aa = snap.team_stats.fetch(:away)

        rows = []

        rows << pastel.dim(format("Possession   HOME %-5.1f%% · AWAY %-5.1f%%", hs[:possession], aa[:possession]))
        rows << pastel.dim(format("Shots        HOME %3d (big chances: #{hs[:big_chances]}) · AWAY %3d (big chances: #{aa[:big_chances]})",
          hs[:shots],
          aa[:shots]))
        rows << pastel.dim(format("Goals        HOME %-3d · AWAY %-3d", hs.fetch(:goals, 0), aa.fetch(:goals, 0)))
        rows.each { |ln| out.puts ln }
        out.puts
      end

      def dossier(report, pastel, out)
        dump_lines(pastel, out, "You", report.managed_strength_lines + report.managed_weak_lines)

        dump_lines(pastel, out, "Them", report.opponent_strength_lines + report.opponent_weak_lines)
        stars(report, pastel, out)
      end

      def dump_lines(pastel, out, tag, lines)
        out.puts pastel.bold(tag)
        lines.take(6).each { |ln| out.puts pastel.white(" • #{ln}") }

        out.puts
      end

      def stars(report, pastel, out)
        out.puts format_face(pastel, "Going well", report.managed_hot[:player])
        out.puts format_face(pastel, "Having a tough one", report.managed_cold[:player])
        out.puts format_face(pastel, "One to watch", report.opponent_hot[:player])
        out.puts format_face(pastel, "Not at their best", report.opponent_cold[:player])
      end

      def format_face(pastel, tag, ply)
        name = ply&.name.to_s.strip
        nm = name.empty? ? "—" : name

        pastel.dim("#{tag}: #{nm}")
      end
    end
  end
end

