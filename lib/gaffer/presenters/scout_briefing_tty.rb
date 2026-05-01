# frozen_string_literal: true

require_relative "../narratives/scout_briefing"

module Gaffer
  module Presenters
    # Conversational scouting screen before XI selection (`gaffer next`).
    module ScoutBriefingTty
      module_function

      # Clears screen, prints briefing, waits for acknowledgement when `prompt` supports it.
      def present(report, pastel:, out: $stdout, prompt: nil)
        out.print("\e[2J\e[H")
        out.puts
        out.puts pastel.bold.white("Scout · #{report.opponent.name}")
        out.puts pastel.dim("─" * 56)
        out.puts

        Narratives::ScoutBriefing.paragraphs(report).each do |chunk|
          out.puts pastel.white(chunk.to_s.strip)
          out.puts
        end

        out.puts pastel.dim("─" * 56)
        out.puts

        if prompt&.respond_to?(:keypress)
          prompt.keypress(pastel.dim("Press any key when you're ready to pick your XI…"))
        else
          out.puts pastel.dim("(non-interactive — continuing to dugout)")
        end
      end
    end
  end
end
