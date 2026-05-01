# frozen_string_literal: true

require "pastel"
require "tty-font"
require "tty-prompt"

require_relative "../commands/play_match"
require_relative "../commands/start_league"
require_relative "../commands/next_fixture"
require_relative "../commands/support/league_reads"
require_relative "onboarding"

module Gaffer
  module Ui
    # Landing screen + menu loop (TTY).
    module Menu
      module_function

      MAIN_MENU_TITLE = "What would you like to do?"
      RETURN_TO_MENU_HINT = "Press any key to return to the menu…"

      def run
        pastel = Pastel.new
        prompt = TTY::Prompt.new
        Gaffer::Database.prepare

        clubs = Repositories::ClubRepository.all

        if Repositories::ManagerRepository.needs_onboarding? && clubs.empty?
          banner_and_seed_warning(pastel, prompt)
          return
        end

        onboarding_if_needed(prompt, pastel, $stdout, clubs)

        loop do
          print "\e[2J\e[H"
          break if main_menu_iteration(pastel:, prompt:, out: $stdout)
        end
      end

      def main_menu_iteration(pastel:, prompt:, out:)
        mgr = Repositories::ManagerRepository.current
        club = mgr && Repositories::ClubRepository.find(mgr.managed_club_id)
        out.puts render_header(pastel, manager: mgr, managed_club: club)
        out.puts

        archived = Repositories::LeagueRepository.completed_ordered
        choice = prompt.select(MAIN_MENU_TITLE) { |menu| register_main_choices(menu, archived) }
        return true if quitting?(choice, pastel, out)

        dispatch_menu_choice(choice, pastel:, prompt:, out:)
        false
      end

      def register_main_choices(menu, archived_seasons)
        active = Repositories::LeagueRepository.active
        append_active_league_choices(menu) if active
        append_archived_choices(menu, archived_seasons)
        menu.choice "Play game", :play
        menu.choice "Start new season", :start_league unless active
        menu.choice "Quit", :quit
      end

      def append_active_league_choices(menu)
        menu.choice "Next fixture · league day", :next_fixture
        menu.choice "League table", :league_table
        menu.choice "Fixtures & results", :season_fixtures
        menu.choice "Top scorers", :top_scorers
      end

      def append_archived_choices(menu, archived_seasons)
        return if archived_seasons.empty?

        menu.choice "Archived league table…", :archived_league_table
        menu.choice "Archived fixtures…", :archived_season_fixtures
      end

      def quitting?(choice, pastel, out)
        return false unless choice == :quit

        out.puts pastel.dim("Goodbye.")
        true
      end

      def dispatch_menu_choice(choice, pastel:, prompt:, out:)
        with_return_pause(pastel, prompt, out) { invoke_menu_action(choice, pastel:, prompt:, out:) }
      end

      def with_return_pause(pastel, prompt, out)
        out.puts
        yield
        out.puts
        prompt.keypress(pastel.dim(RETURN_TO_MENU_HINT))
      end

      def invoke_menu_action(choice, pastel:, prompt:, out:)
        case choice
        when :next_fixture
          Gaffer::Commands::NextFixture.run(pastel:, out:, prompt:)
        when :archived_league_table
          Gaffer::Commands::Support::LeagueReads.from_menu_standings_archive(pastel:, out:, prompt:)
        when :league_table
          Gaffer::Commands::Support::LeagueReads.from_menu_standings_active(pastel:, out:)
        when :season_fixtures
          Gaffer::Commands::Support::LeagueReads.from_menu_fixtures_active(pastel:, out:)
        when :top_scorers
          Gaffer::Commands::Support::LeagueReads.from_menu_scorers_active(pastel:, out:)
        when :archived_season_fixtures
          Gaffer::Commands::Support::LeagueReads.from_menu_fixtures_archive(pastel:, out:, prompt:)
        when :start_league
          Gaffer::Commands::StartLeague.run(pastel:, out:)
        when :play
          Gaffer::Commands::PlayMatch.run(pastel:, out:)
        end
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
