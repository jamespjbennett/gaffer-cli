# frozen_string_literal: true

module Gaffer
  module Narratives
    module BoardReaction
      # Facts for rule-based board copy (immutable).
      Context = Data.define(
        :managed_club,
        :opponent_club,
        :home_score,
        :away_score,
        :hosting_managed,
        :managed_rank,
        :opponent_rank,
        :league_size
      ) do
        def managed_goals = hosting_managed ? home_score.to_i : away_score.to_i

        def opponent_goals = hosting_managed ? away_score.to_i : home_score.to_i

        def managed_win? = managed_goals > opponent_goals

        def managed_loss? = managed_goals < opponent_goals

        def margin = (managed_goals - opponent_goals).abs

        def opponent_strong? = opponent_rank <= 3

        def opponent_weak? = opponent_rank >= league_size - 2

        def we_above_them_in_table? = managed_rank < opponent_rank

        def they_above_us_in_table? = opponent_rank < managed_rank
      end
    end
  end
end
