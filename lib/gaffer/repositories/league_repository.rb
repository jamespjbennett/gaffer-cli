# frozen_string_literal: true

module Gaffer
  module Repositories
    class LeagueRepository < Base
      class << self
        def find(id)
          row = ds.where(id:).first
          row ? row_to_domain(row) : nil
        end

        # At most one should be `:active`; returns the lowest-id active row if several exist (data bug).
        def active
          row = ds.where(status: "active").order(:id).first
          row ? row_to_domain(row) : nil
        end

        def save(league)
          attrs = domain_to_attrs(league)
          if league.id
            ds.where(id: league.id).update(attrs)
            row_to_domain(ds.where(id: league.id).first)
          else
            new_id = ds.insert(attrs)
            row_to_domain(ds.where(id: new_id).first)
          end
        end

        def complete!(id)
          ds.where(id:).update(status: "complete")
          find(id)
        end

        def latest_year
          row = ds.order(Sequel.desc(:year)).first
          row ? row[:year] : nil
        end

        private

        def ds
          db[:leagues]
        end

        def row_to_domain(row)
          Domain::League.new(
            id: row[:id],
            name: row[:name],
            year: row[:year],
            status: symbol_or_nil(row[:status]),
            current_gameweek: row[:current_gameweek]
          )
        end

        def domain_to_attrs(league)
          {
            name: league.name.to_s,
            year: league.year.to_i,
            status: normalize_status(league.status),
            current_gameweek: league.current_gameweek.nil? ? 1 : league.current_gameweek.to_i
          }
        end

        def normalize_status(sym)
          s = symbol_or_nil(sym)
          unless s.nil? || Domain::LEAGUE_STATUSES.include?(s)
            raise ArgumentError, "invalid league status #{sym.inspect}"
          end

          s&.to_s || "pending"
        end
      end
    end
  end
end
