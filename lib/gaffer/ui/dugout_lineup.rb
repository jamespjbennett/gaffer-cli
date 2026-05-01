# frozen_string_literal: true

require_relative "../domain/lineup"
require_relative "../presenters/matchday_squad"

module Gaffer
  module Ui
    # Interactive dugout: confirm or edit the starting XI (TTY prompts + [`Presenters::MatchdaySquad`] output).
    module DugoutLineup
      class << self
        # @param preset [Array<Domain::Player>, nil] tests / headless: skip UI when valid against full_squad
        # @return [Array<Domain::Player>, nil] eleven players, or nil if preset was invalid
        def resolve(preset:, suggested_xi:, full_squad:, club:, prompt:, pastel:, out:, gameweek:, opponent:, hosting:)
          locked = validate_preset_lineup(preset, full_squad)
          return locked if locked

          xi = suggested_xi.dup

          Presenters::MatchdaySquad.print_heading(
            out: out, pastel: pastel, club: club, gameweek: gameweek,
            opponent: opponent, hosting: hosting
          )

          Presenters::MatchdaySquad.print_roster_note(out: out, pastel: pastel)
          Presenters::MatchdaySquad.print_full_squad_table(out: out, pastel: pastel, players: full_squad)
          Presenters::MatchdaySquad.print_xi_heading(out: out, pastel: pastel)
          Presenters::MatchdaySquad.print_xi_lines(out: out, pastel: pastel, xi: xi)

          unless prompt&.respond_to?(:yes?)
            out.puts pastel.dim("Non-interactive shell — auto-starting suggested XI.")
            return xi
          end

          if prompt.yes?(pastel.bold("Start with this XI?"), default: true)
            refresh_after_xi_locked(
              out: out, pastel: pastel, club: club, gameweek: gameweek,
              opponent: opponent, hosting: hosting, xi: xi
            )
            return xi
          end

          unless prompt.respond_to?(:select)
            out.puts pastel.dim("TTY select unavailable — keeping suggested XI.")
            return xi
          end

          loop do
            # Hash entries — plain [label, value] pairs break: tty-prompt flattens args and splits tuples.
            slot_payload = [
              { name: "Lineup confirmed — continue", value: :done }
            ] + Domain::Lineup::XI_SLOT_LABELS.each_with_index.map do |lbl, idx|
              { name: "Change #{lbl} · #{xi[idx].name}", value: idx }
            end

            slot_pick = prompt.select(pastel.bold("Adjust your XI"), slot_payload, cycle: true)
            break if slot_pick == :done

            slot_idx = Integer(slot_pick)
            desired_pos = Domain::Lineup::FORMATION_SLOTS[slot_idx]
            current = xi[slot_idx]

            other_ids =
              xi.each_with_index.each_with_object([]) do |(pl, j), arr|
                arr << pl.id if j != slot_idx
              end

            pool = full_squad.reject { |pl| other_ids.include?(pl.id) }
            pos_fit = pool.select { |pl| pl.position&.to_sym == desired_pos }
            roster = pos_fit.empty? ? pool : pos_fit

            replacement_payload =
              [{ name: "(stay on #{current.name})", value: current }] +
              roster.reject { |pl| pl.id == current.id }
                    .sort_by { |pl| [-Domain::Lineup.grade_scalar(pl)] }
                    .map { |pl| { name: "#{pl.name}  OVR #{pl.overall}", value: pl } }

            replacement = prompt.select(
              pastel.bold("Who wears #{Domain::Lineup::XI_SLOT_LABELS[slot_idx]} (#{desired_pos.upcase})?"),
              replacement_payload,
              cycle: true
            )

            xi[slot_idx] = replacement
          end

          refresh_after_xi_locked(
            out: out, pastel: pastel, club: club, gameweek: gameweek,
            opponent: opponent, hosting: hosting, xi: xi
          )

          xi
        end

        private

        def validate_preset_lineup(preset, squad)
          return nil if preset.nil?

          list = preset.is_a?(Array) ? preset : nil
          return nil unless list && list.size == 11

          allowed_ids = squad.each_with_object({}) { |pl, acc| acc[pl.id] = true }
          seen = {}

          canon =
            list.map do |maybe|
              return nil unless maybe.respond_to?(:id)

              id = maybe.id
              return nil unless allowed_ids[id]
              return nil if seen[id]

              seen[id] = true
              row = squad.find { |s| s.id == id }
              return nil unless row

              row
            end

          canon
        end

        def refresh_after_xi_locked(out:, pastel:, club:, gameweek:, opponent:, hosting:, xi:)
          out.print("\e[2J\e[H")
          Presenters::MatchdaySquad.print_heading(
            out: out, pastel: pastel, club: club, gameweek: gameweek,
            opponent: opponent, hosting: hosting
          )
          out.puts pastel.dim("Squad list hidden — XI locked.")
          Presenters::MatchdaySquad.print_xi_heading(out: out, pastel: pastel)
          Presenters::MatchdaySquad.print_xi_lines(out: out, pastel: pastel, xi: xi)
        end
      end
    end
  end
end
