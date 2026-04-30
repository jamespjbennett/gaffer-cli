# frozen_string_literal: true

module Gaffer
  module Commands
    # Resolves which league row to show for `table` / `fixtures` (active, --previous, --year, explicit).
    module SeasonLookup
      module_function

      # @return [Domain::League, nil]
      def resolve(league:, previous:, year:, out:, pastel:)
        return league if league

        if !year.nil?
          y = Integer(year)
          lg = Repositories::LeagueRepository.find_for_calendar_year(y)
          unless lg
            out.puts pastel.red("No saved league for calendar year #{y}.")
            return nil
          end

          return lg
        end

        if previous
          hist = Repositories::LeagueRepository.completed_ordered
          if hist.empty?
            out.puts pastel.dim("No completed leagues in the database yet.")
            return nil
          end

          return hist.first
        end

        Repositories::LeagueRepository.active
      rescue ArgumentError, TypeError
        out.puts pastel.red("Year must be an integer (#{year.inspect}).")
        nil
      end
    end
  end
end
