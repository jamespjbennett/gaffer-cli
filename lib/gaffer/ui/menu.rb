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
        menu.choice "Play test game", :play
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
        MenuHeader.assemble(pastel, manager:, managed_club:)
      end
    end

    # Block-font hero + ruler + subtitle for [`Menu`].
    module MenuHeader
      class << self
        RULE_CHAR = "─"

        # @return [String] frozen multiline banner
        def assemble(pastel, manager:, managed_club:)
          lines, width = ascii_title_geometry
          rule = pastel.dim(rule_bar(width))

          banner = +""
          banner << "\n#{boxed_core(rule, pastel, lines, width)}"
          banner << "#{manager_sentence(pastel, manager:, managed_club:, width:)}" if mgr_pair?(manager, managed_club)
          banner << "#{rule}\n"
          banner.freeze
        end

        private

        def ascii_title_geometry
          font = TTY::Font.new(:block)
          raw = font.write("GAFFER").lines.map(&:rstrip).reject(&:empty?)
          span = raw.map(&:length).max.to_i
          span = 1 if span < 1
          [raw, span]
        end

        def rule_bar(width)
          RULE_CHAR * width
        end

        def boxed_core(rule, pastel, lines, width)
          "#{rule}\n#{tinted_logo(pastel, lines)}\n#{cli_row(pastel, width)}\n#{tag_row(pastel, width)}\n"
        end

        def tinted_logo(pastel, lines)
          lines.map { |ln| pastel.bold.white(ln) }.join("\n")
        end

        def cli_row(pastel, width)
          pastel.bold.white("CLI".center(width))
        end

        def tag_row(pastel, width)
          plain = version_tag_plain(width)
          pastel.dim(plain)
        end

        def version_tag_plain(width)
          txt = +"Football management  ·  v#{Gaffer::VERSION}"
          txt.length <= width ? txt.center(width) : txt
        end

        def mgr_pair?(manager, club)
          manager && club
        end

        def manager_sentence(pastel, manager:, managed_club:, width:)
          body = +"#{manager.display_name.strip} · managing #{managed_club.name}".strip
          tinted = body.length <= width ? pastel.dim(body.center(width)) : pastel.dim(body)
          "#{tinted}\n"
        end
      end
    end
  end
end
