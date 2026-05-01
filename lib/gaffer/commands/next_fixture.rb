# frozen_string_literal: true

require "pastel"

require_relative "gameweek_play"

module Gaffer
  module Commands
    # CLI / menu entry for `gaffer next`: ensures SQLite is ready, then runs one league gameweek via
    # [`GameweekPlay`].
    module NextFixture
      class << self
        # @param pastel [Pastel]
        # @param out [IO]
        # @param prompt [#yes?, #select, nil] interactive TTY from the menu where available.
        # @param manager_tactic [Symbol, nil] when set (e.g. tests), skips the tactic menu and uses this shape.
        # @param manager_lineup [Array<Domain::Player>, nil] eleven players from your club to skip dugout UI & validation
        # @return [Symbol] `:ok`, `:no_active_league`, `:no_manager`, `:squads_incomplete`,
        #   `:fixture_data_error`, or `:season_completed`
        def run(pastel: Pastel.new, out: $stdout, prompt: nil, manager_tactic: nil, manager_lineup: nil)
          ensure_db_connected
          GameweekPlay.run(
            pastel: pastel,
            out: out,
            prompt: prompt,
            manager_tactic: manager_tactic,
            manager_lineup: manager_lineup
          )
        end

        private

        def ensure_db_connected
          Gaffer::Database.connect
          Gaffer::Database.migrate
        end
      end
    end
  end
end
