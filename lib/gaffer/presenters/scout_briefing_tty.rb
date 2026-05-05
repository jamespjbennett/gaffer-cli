# frozen_string_literal: true

require_relative "../narratives/scout_briefing"
require_relative "../narratives/coach_training_report"
require_relative "scout_report_tty"

module Gaffer
  module Presenters
    # Conversational scouting screen before XI selection (`gaffer next`).
    module ScoutBriefingTty
      module_function

      def present(report, pastel:, out: $stdout, prompt: nil, coaching: nil)
        prelude(report, pastel, out)
        divider(pastel, out)
        training(coaching, pastel, out) unless coaching.nil?
        divider(pastel, out)
        await(prompt, pastel, out)
      end

      def prelude(report, pastel, out)
        wipe(out)
        ScoutReportTty.render(report, pastel:, out:)
        body(Narratives::ScoutBriefing.paragraphs(report), pastel, out)
      end

      def replay_dugout(report, pastel:, out:, coaching: nil, prompt: nil)
        full_brief(report, pastel, out, coaching)
        pause_return(prompt, pastel, out)
      end

      def full_brief(report, pastel, out, coaching)
        prelude(report, pastel, out)
        divider(pastel, out)
        training(coaching, pastel, out) unless coaching.nil?
        divider(pastel, out)
      end

      def pause_return(prompt, pastel, out)
        return stdin_fallback(out, pastel) unless prompt&.respond_to?(:keypress)

        prompt.keypress(pastel.dim("Press any key to return to XI selection…"))
      end

      def stdin_fallback(out, pastel)
        out.puts pastel.dim("(non-interactive — returning to XI selection)")
      end

      def wipe(out)
        out.print("\e[2J\e[H")
        out.puts
      end

      def body(chunks, pastel, out)
        chunks.each { |c| print_chunk(c, pastel, out) }
      end

      def print_chunk(chunk, pastel, out)
        out.puts pastel.white(chunk.to_s.strip)
        out.puts
      end

      def divider(pastel, out)
        out.puts pastel.dim("─" * 56)
        out.puts
      end

      def training(coaching, pastel, out)
        out.puts pastel.bold.white("Coach · #{coach_label(coaching)}")
        out.puts
        Narratives::CoachTrainingReport.paragraphs(coaching).each { |c| print_chunk(c, pastel, out) }
      end

      def coach_label(ctx)
        s = ctx.managed_club.short_name.to_s.strip
        s.empty? ? ctx.managed_club.name.to_s : s
      end

      def await(prompt, pastel, out)
        if prompt&.respond_to?(:keypress)
          prompt.keypress(pastel.dim("Press any key when you're ready to pick your XI…"))
        else
          out.puts pastel.dim("(non-interactive — continuing to dugout)")
        end
      end
    end
  end
end
