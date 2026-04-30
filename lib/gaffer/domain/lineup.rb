# frozen_string_literal: true

module Gaffer
  module Domain
    # Picks an 11 (4-3-3: 1+4+3+3). MatchEngine averages the players you pass, so simulations use XI only.
    module Lineup
      module_function

      FORMATION_SLOTS = (
        [:gk] + ([:def] * 4) + ([:mid] * 3) + ([:att] * 3)
      ).freeze

      XI_SLOT_LABELS = %w[
        GK D1 D2 D3 D4 M1 M2 M3 A1 A2 A3
      ].freeze

      # @param players [Array<Domain::Player>]
      # @return [Array<Domain::Player>]
      def pick_best_xi(players)
        return [] if players.nil? || players.empty?

        used_keys = []
        xi = []

        FORMATION_SLOTS.each do |pos|
          pick = choose_one(players, pos, used_keys)
          return [] unless pick

          used_keys << dedupe_key(pick)
          xi << pick
        end

        xi
      end

      # Stable identity when `Player#id` is nil (tests / ephemeral structs).
      def dedupe_key(player)
        pk = player&.id
        pk.nil? ? player.object_id : pk
      end

      def grade_scalar(player)
        return 0 unless player

        o = player.overall.to_i.clamp(1, 99)
        f = player.form.to_i.clamp(1, 10)
        p = player.potential.to_i.clamp(1, 99)
        (o << 14) | (f << 7) | p
      end

      def choose_one(players, pos_sym, used_keys)
        pool = players.reject { |pl| used_keys.include?(dedupe_key(pl)) }
        return nil if pool.empty?

        in_line = pool.select { |pl| normalized_position(pl) == pos_sym }
        bucket = in_line.empty? ? pool : in_line
        bucket.max_by { |pl| grade_scalar(pl) }
      end

      def normalized_position(player)
        player&.position&.to_sym
      end

      private_class_method :choose_one, :normalized_position
    end
  end
end
