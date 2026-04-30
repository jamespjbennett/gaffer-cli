# frozen_string_literal: true

require "tty-table"

module Gaffer
  module Presenters
    # Fixtures + scores for one league row (played vs scheduled).
    module SeasonFixturesTty
      module_function

      # @param pairs [Array<Array(Domain::Fixture, Domain::Match, nil)>]
      # @param clubs_by_id [Hash{Integer => Domain::Club}]
      # @param managed_club_id [Integer, nil]
      # @return [String]
      def render(pairs:, clubs_by_id:, pastel:, managed_club_id: nil)
        return pastel.dim("(no fixtures scheduled for this season.)") if pairs.nil? || pairs.empty?

        mid = managed_club_id.to_i

        rows =
          pairs.map do |fx, match|
            hid = fx.home_club_id.to_i
            aid = fx.away_club_id.to_i
            hs = cell_short(clubs_by_id:, cid: hid, pastel:, managed_id: mid)
            a_s = cell_short(clubs_by_id:, cid: aid, pastel:, managed_id: mid)
            score =
              if !fx.played?
                pastel.dim("— · —")
              elsif match.nil?
                pastel.red("? · ?")
              else
                "#{pastel.bold(match.home_score)}–#{pastel.bold(match.away_score)}"
              end

            you = involvement_marker(hid, aid, mid, pastel)

            [
              pastel.dim(fx.gameweek.to_s.rjust(2)),
              hs,
              score,
              a_s,
              you
            ]
          end

        table = TTY::Table.new(
          header: [
            pastel.bold("GW"),
            pastel.bold("Home"),
            pastel.bold("Score"),
            pastel.bold("Away"),
            pastel.dim("You")
          ],
          rows: rows
        )

        table.render(:unicode, padding: [0, 1], alignment: [:center, :left, :center, :left, :center])
      end

      def cell_short(clubs_by_id:, cid:, pastel:, managed_id:)
        c = clubs_by_id[cid]
        raw = (c&.short_name || "?").to_s
        label = raw.length <= 10 ? raw : "#{raw[..6]}…"
        managed_id.positive? && cid.to_i == managed_id ? pastel.bold.green(label) : label
      end

      def involvement_marker(hid, aid, mid, pastel)
        return "" unless mid.positive?

        hid == mid || aid == mid ? pastel.yellow("•") : ""
      end
    end
  end
end
