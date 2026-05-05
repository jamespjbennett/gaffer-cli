# frozen_string_literal: true

module Gaffer
  module Presenters
    # Separate FT screen — board view before returning to menu.
    module BoardReactionTty
      module_function

      def present(note, pastel:, out:, prompt:)
        wipe(out)
        out.puts pastel.bold.white("From the board")
        out.puts pastel.dim("─" * 56)
        out.puts pastel.white(note.to_s.strip)
        out.puts
        pause(prompt, pastel, out)
      end

      def wipe(io)
        io.print("\e[2J\e[H")
        io.puts
      end

      def pause(prompt, pastel, out)
        return prompt.keypress(pastel.dim("Continue →")) if prompt.respond_to?(:keypress)

        out.puts pastel.dim("(auto)")
      end
    end
  end
end
