# frozen_string_literal: true

require "pastel"

require_relative "support/season_lookup"

module Gaffer
  module Commands
    # `gaffer table` — active league by default, or an archived season (`--previous`, `--year`).
    #
    # @see CLAUDE.md Phase 1b Step 6
    module LeagueStandings
      class << self
        # @param league [Domain::League, nil] when set, shows that row directly
        # @param previous [Boolean] newest `:complete` league
        # @param year [Integer, nil] most recent league row for this calendar year
        # @return [Symbol] `:ok`, `:no_active_league`, or `:no_standings_target`
        def run(pastel: Pastel.new, out: $stdout, league: nil, previous: false, year: nil)
          Gaffer::Database.prepare

          target = SeasonLookup.resolve(league:, previous:, year:, out:, pastel:)

          unless target
            if year.nil? && !previous
              out.puts pastel.dim("No active league — start a season to see the table.")
              return :no_active_league
            end

            return :no_standings_target
          end

          mgr = Repositories::ManagerRepository.current
          managed_id = mgr&.managed_club_id&.to_i

          results = Repositories::FixtureRepository.settled_scores_for_season(target.id)
          club_count = Repositories::FixtureRepository.club_ids_for_season(target.id).size

          out.puts
          tag =
            if target.complete?
              pastel.dim(" · archived")
            elsif target.active?
              pastel.dim(" · live")
            else
              pastel.dim(" · #{target.status}")
            end

          out.puts pastel.bold.white("#{target.name} · #{target.year}") + tag + pastel.dim("  (#{club_count} clubs)")
          out.puts Presenters::LeagueTableTty.render_for_season(
            league_id: target.id,
            pastel: pastel,
            managed_club_id: managed_id
          )

          state = target.complete? ? "final table" : "in progress"
          out.puts pastel.dim("(#{state} · #{results.size} results settled).")
          out.puts
          :ok
        end
      end
    end
  end
end
