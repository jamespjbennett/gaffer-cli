# frozen_string_literal: true

require "pastel"

require_relative "support/season_lookup"

module Gaffer
  module Commands
    # `gaffer scorers` — chart for the active league (or `--previous` / `--year`, like `table`).
    module TopScorers
      DISPLAY_LIMIT = 20

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

          totals = Repositories::GoalEventRepository.totals_by_player(target.id)

          out.puts
          tag =
            if target.complete?
              pastel.dim(" · archived")
            elsif target.active?
              pastel.dim(" · live")
            else
              pastel.dim(" · #{target.status}")
            end

          out.puts pastel.bold.white("#{target.name} · #{target.year}") + tag + pastel.dim("  · top scorers")

          if totals.empty?
            out.puts pastel.dim("No goals recorded this season yet.")
            out.puts
            return :ok
          end

          slice = totals.first(DISPLAY_LIMIT)
          rows = hydrated_rows(slice)
          out.puts Presenters::TopScorersTty.render(pastel:, rows:, managed_club_id: managed_id)
          goal_sum = totals.sum { |t| t[:goals] }
          tail =
            if totals.size > DISPLAY_LIMIT
              " · showing top #{DISPLAY_LIMIT} of #{totals.size} scorers"
            else
              " · #{rows.size} players on the chart"
            end
          out.puts pastel.dim("#{goal_sum} goals#{tail}.")
          out.puts
          :ok
        end

        private

        def hydrated_rows(totals)
          built = []
          totals.each do |t|
            pl = Repositories::PlayerRepository.find(t[:player_id])
            next unless pl

            cl = Repositories::ClubRepository.find(pl.club_id)
            built << {
              name: pl.name.to_s,
              club: cl&.name.to_s,
              goals: t[:goals],
              player_club_id: pl.club_id.to_i
            }
          end

          built.each_with_index.map { |r, i| r.merge(pos: i + 1) }
        end
      end
    end
  end
end
