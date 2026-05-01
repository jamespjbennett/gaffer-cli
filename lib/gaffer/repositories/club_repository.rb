# frozen_string_literal: true

module Gaffer
  module Repositories
    class ClubRepository < Base
      class << self
        def find(id)
          row = clubs_ds.where(id:).first
          row ? row_to_domain(row) : nil
        end

        # @param short [String] normalised with +strip+ then +upcase+
        # @return [Domain::Club, nil]
        def find_by_short_name(short)
          norm = short.to_s.strip.upcase
          return nil if norm.empty?

          row = clubs_ds.where(short_name: norm).first
          row ? row_to_domain(row) : nil
        end

        def all
          clubs_ds.order(:name).map { row_to_domain(_1) }
        end

        def for_league(league_id)
          lid = league_id.to_i
          clubs_ds.where(league_id: lid).order(:name).map { row_to_domain(_1) }
        end

        # Ordered roster by id list (historical leagues where `league_id` column no longer matches).
        def for_ids_ordered(ids)
          uniq = Array(ids).map(&:to_i).uniq
          return [] if uniq.empty?

          clubs_ds.where(id: uniq).order(:name).map { row_to_domain(_1) }
        end

        def save(club)
          attrs = domain_to_attrs(club)
          if club.id
            clubs_ds.where(id: club.id).update(attrs)
            row_to_domain(clubs_ds.where(id: club.id).first)
          else
            new_id = clubs_ds.insert(attrs)
            row_to_domain(clubs_ds.where(id: new_id).first)
          end
        end

        def assign_all_to_league!(league_id)
          clubs_ds.update(league_id: league_id.to_i)
        end

        private

        def clubs_ds
          db[:clubs]
        end

        def row_to_domain(row)
          Domain::Club.new(
            id: row[:id],
            name: row[:name],
            short_name: row[:short_name],
            league_id: row[:league_id],
            reputation: row[:reputation],
            budget: row[:budget],
            wage_budget: row[:wage_budget],
            stadium: row[:stadium],
            chairman_name: row[:chairman_name],
            chairman_mood: symbol_or_nil(row[:chairman_mood]),
            board_target: symbol_or_nil(row[:board_target])
          )
        end

        def domain_to_attrs(club)
          {
            name: club.name,
            short_name: club.short_name,
            league_id: club.league_id,
            reputation: club.reputation.nil? ? 50 : club.reputation,
            budget: club.budget.nil? ? 0 : club.budget,
            wage_budget: club.wage_budget.nil? ? 0 : club.wage_budget,
            stadium: club.stadium,
            chairman_name: club.chairman_name,
            chairman_mood: club.chairman_mood&.to_s,
            board_target: club.board_target&.to_s
          }
        end
      end
    end
  end
end
