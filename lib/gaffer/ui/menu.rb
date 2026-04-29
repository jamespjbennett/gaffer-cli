# frozen_string_literal: true

require "pastel"
require "tty-prompt"

require_relative "../commands/play_match"

module Gaffer
  module Ui
    # Landing screen + menu loop (TTY).
    module Menu
      module_function

      def run
        pastel = Pastel.new
        prompt = TTY::Prompt.new

        loop do
          print "\e[2J\e[H"
          out = $stdout
          out.puts render_header(pastel)
          out.puts

          choice = prompt.select("What would you like to do?") do |menu|
            menu.choice "Play game", :play
            menu.choice "Quit", :quit
          end

          case choice
          when :play
            out.puts
            Gaffer::Commands::PlayMatch.run(pastel:)
            out.puts
            prompt.keypress(pastel.dim("Press any key to return to the menu…"))
          when :quit
            out.puts pastel.dim("Goodbye.")
            break
          end
        end
      end

      def render_header(pastel)
        v = Gaffer::VERSION
        <<~BANNER

          #{pastel.dim("─" * 46)}
               #{pastel.bold.white("GAFFER")}
          #{pastel.bold.cyan("               CLI")}
          #{pastel.dim("    Football management  ·  v#{v}")}
          #{pastel.dim("─" * 46)}
        BANNER
      end
    end
  end
end
