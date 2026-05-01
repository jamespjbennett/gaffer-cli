# frozen_string_literal: true

module Gaffer
  module Commands
    module Support
      # Watch-list player for scout copy (scorer / live-wire / enforcer fallback).
      module ScoutWatchFocus
        class << self
          def pick(top_scorer:, opp_players:)
            row = scorer_focus(top_scorer)
            return row if row

            pulse_focus(opp_players)
          end

          private

          def scorer_focus(top)
            return unless top && top[:goals].to_i.positive?

            {
              player: top[:player],
              kind: :scorer,
              goals: top[:goals].to_i
            }
          end

          def pulse_focus(opp_players)
            list = opp_players.reject { |pl| pl.position&.to_sym == :gk }
            return nil if list.empty?

            att_mid = list.select { |pl| %i[att mid].include?(pl.position&.to_sym) }
            fwd = att_mid.empty? ? list : att_mid

            live = fwd.max_by { |pl| iv(pl, :shooting) + iv(pl, :pace) + iv(pl, :dribbling) }
            return livewire_pair(live) if live

            rock = defs_enforcer(list)
            return enforcer_pair(rock) if rock

            livewire_pair(list.first)
          end

          def defs_enforcer(list)
            list
              .select { |pl| pl.position&.to_sym == :def }
              .max_by { |pl| iv(pl, :defending) || 0 }
          end

          def livewire_pair(player)
            { player: player, kind: :livewire, goals: nil }
          end

          def enforcer_pair(player)
            { player: player, kind: :enforcer, goals: nil }
          end

          def iv(player, attr)
            v = player.public_send(attr)
            v.nil? ? 62 : v.to_i.clamp(1, 99)
          end
        end
      end
    end
  end
end
