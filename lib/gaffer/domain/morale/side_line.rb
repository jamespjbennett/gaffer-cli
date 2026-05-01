# frozen_string_literal: true

require_relative "concede_hits"
require_relative "form_norm"
require_relative "morale_step"

module Gaffer
  module Domain
    module Morale
      module SideLine
        module_function

        def player_updates(xi:, goals_for:, goals_against:, scorers:, rng:)
          tally = scorer_tally(scorers)
          marks = ConcedeHits.defender_hits(xi, goals_against, rng)
          out = side_outcome(goals_for, goals_against)
          xi.each_with_object({}) do |pl, acc|
            acc[pl.id] = row_for(pl, tally, marks, goals_against, out)
          end
        end

        def scorer_tally(scorers)
          scorers.filter_map { |p| p&.id.to_i.nonzero? }.tally
        end

        def side_outcome(gf, ga)
          return :win if gf > ga
          return :loss if gf < ga
          :draw
        end

        def row_for(pl, tally, marks, ga, out)
          fd, ms = event_pair(pl, tally, marks, ga, out)
          fd += passive_shift(fd, pl)
          form = (FormNorm.clamped(pl) + fd).clamp(1, 10)
          { form: form, morale: MoraleStep.apply_shift(pl.morale, ms) }
        end

        def event_pair(pl, tally, marks, ga, out)
          fd, ms = base_events(pl, tally, ga, out)
          [fd - marks.fetch(pl.id, 0), ms]
        end

        def base_events(pl, tally, ga, out)
          acc = [0, result_morale(out)]
          acc = apply_scorer(pl, tally, *acc)
          acc = apply_sheet(pl, ga, *acc)
          [concede_gk(pl, ga, acc[0]), acc[1]]
        end

        def result_morale(out)
          return 1 if out == :win
          return -1 if out == :loss
          0
        end

        def apply_scorer(pl, tally, fd, ms)
          return [fd, ms] unless tally.fetch(pl.id, 0).positive?
          [fd + 1, ms + 1]
        end

        def apply_sheet(pl, ga, fd, ms)
          return [fd, ms] unless ga.zero? && backs?(pl)
          [fd + 1, ms + 1]
        end

        def backs?(pl)
          %i[gk def].include?(pl.position&.to_sym)
        end

        def concede_gk(pl, ga, fd)
          return fd unless pl.position&.to_sym == :gk
          fd - ga
        end

        def passive_shift(event_fd, pl)
          return 0 unless event_fd.zero?
          norm = FormNorm.clamped(pl)
          return 0 if norm == 5
          norm > 5 ? -1 : 1
        end
      end
    end
  end
end
