# frozen_string_literal: true

require "pastel"
require "tty-font"
require "tty-prompt"

require_relative "../commands/play_match"
require_relative "../commands/start_league"
require_relative "../commands/next_fixture"
require_relative "onboarding"

module Gaffer
  module Ui
    # Landing screen + menu loop (TTY).
    module Menu
      module_function

      def run
        pastel = Pastel.new
        prompt = TTY::Prompt.new
        connect_and_migrate

        clubs = Repositories::ClubRepository.all

        if Repositories::ManagerRepository.needs_onboarding? && clubs.empty?
          banner_and_seed_warning(pastel, prompt)
          return
        end

        onboarding_if_needed(prompt, pastel, $stdout, clubs)

        loop do
          print "\e[2J\e[H"
          out = $stdout

          mgr = Repositories::ManagerRepository.current
          club =
            mgr && Repositories::ClubRepository.find(mgr.managed_club_id)

          out.puts render_header(pastel, manager: mgr, managed_club: club)
          out.puts

          choice = prompt.select("What would you like to do?") do |menu|
            menu.choice "Next fixture · league day", :next_fixture if Repositories::LeagueRepository.active
            menu.choice "Play game", :play
            menu.choice "Start new season", :start_league unless Repositories::LeagueRepository.active
            menu.choice "Quit", :quit
          end

          case choice
          when :next_fixture
            out.puts
            Gaffer::Commands::NextFixture.run(pastel:, out: out, prompt: prompt)
            out.puts
            prompt.keypress(pastel.dim("Press any key to return to the menu…"))
          when :start_league
            out.puts
            Gaffer::Commands::StartLeague.run(pastel:, out: out)
            out.puts
            prompt.keypress(pastel.dim("Press any key to return to the menu…"))
          when :play
            out.puts
            Gaffer::Commands::PlayMatch.run(pastel:, out: out)
            out.puts
            prompt.keypress(pastel.dim("Press any key to return to the menu…"))
          when :quit
            out.puts pastel.dim("Goodbye.")
            break
          end
        end
      end

      def connect_and_migrate
        Gaffer::Database.connect
        Gaffer::Database.migrate
      end

      def banner_and_seed_warning(pastel, prompt)
        print "\e[2J\e[H"
        pastel_obj = pastel
        $stdout.puts pastel_obj.bold.red("There are no clubs in the database.")
        $stdout.puts pastel_obj.dim("Run migrations and seed fictional teams:")
        $stdout.puts pastel_obj.dim("  bundle exec rake db:seed")
        $stdout.puts
        prompt.keypress(pastel_obj.dim("Press any key to quit…"))
      end

      def onboarding_if_needed(prompt, pastel, out, clubs)
        return unless Repositories::ManagerRepository.needs_onboarding?

        Onboarding.run!(prompt:, pastel:, out:, clubs:)
      end

      def render_header(pastel, manager:, managed_club:)
        v = Gaffer::VERSION
        block_font = TTY::Font.new(:block)
        title_lines = block_font.write("GAFFER").lines.map(&:rstrip).reject(&:empty?)
        width = title_lines.map(&:length).max.to_i
        width = 1 if width < 1
        rule = pastel.dim("─" * width)

        body = title_lines.map { |line| pastel.bold.white(line) }.join("\n")
        cli = pastel.bold.white("CLI".center(width))
        tag = "Football management  ·  v#{v}"
        tag_plain = tag.length <= width ? tag.center(width) : tag
        tag_line = pastel.dim(tag_plain)

        manager_line =
          if manager && managed_club
            snippet = "#{manager.display_name.strip} · managing #{managed_club.name}".strip
            snippet.length <= width ? pastel.dim(snippet.center(width)) : pastel.dim(snippet)
          else
            nil
          end

        banner = +""
        banner << "\n#{rule}\n#{body}\n#{cli}\n#{tag_line}\n"
        banner << "#{manager_line}\n" if manager_line
        banner << "#{rule}\n"
        banner.freeze
      end
    end
  end
end
