# frozen_string_literal: true

require "pastel"

require_relative "support/season_lookup"

module Gaffer
  module Commands
    # `gaffer fixtures` — fixtures and results for the active league (--previous / --year like `table`).
    module SeasonFixtures
      class << self
        # @return [Symbol] `:ok`, `:no_active_league`, or `:no_standings_target`
        def run(pastel: Pastel.new, out: $stdout, league: nil, previous: false, year: nil)
          Gaffer::Database.connect
          Gaffer::Database.migrate

          target = SeasonLookup.resolve(league:, previous:, year:, out:, pastel:)

          unless target
            if year.nil? && !previous && league.nil?
              out.puts pastel.dim("No active league — start a season or use --previous / --year.")
              return :no_active_league
            end

            return :no_standings_target
          end

          mgr = Repositories::ManagerRepository.current
          managed_id = mgr&.managed_club_id&.to_i

          pairs = Repositories::FixtureRepository.fixtures_with_matches_for_season(target.id)
          club_ids = Repositories::FixtureRepository.club_ids_for_season(target.id)
          clubs_by_id = Repositories::ClubRepository.for_ids_ordered(club_ids).each_with_object({}) { |c, acc| acc[c.id] = c }

          played = pairs.count { |fx, _| fx.played? }
          total = pairs.size

          out.puts
          tag =
            if target.complete?
              pastel.dim(" · archived")
            elsif target.active?
              pastel.dim(" · live")
            else
              pastel.dim(" · #{target.status}")
            end

          headline = +"#{pastel.bold.white("#{target.name} · #{target.year}")}#{tag}"
          headline << pastel.dim("  · GW #{target.current_gameweek}") if target.active?

          out.puts headline

          out.puts pastel.dim("#{played}/#{total} fixtures played.") if total.positive?
          out.puts Presenters::SeasonFixturesTty.render(pairs:, clubs_by_id:, pastel:, managed_club_id: managed_id)
          out.puts pastel.dim("'You': games involving your club (short names in bold).")
          out.puts

          :ok
        end
      end
    end
  end
end
