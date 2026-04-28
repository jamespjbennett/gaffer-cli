# frozen_string_literal: true

module Gaffer
  module Repositories
    class PlayerRepository < Base
      class << self
        def find(id)
          row = players_ds.where(id:).first
          row ? row_to_domain(row) : nil
        end

        def for_club(club_id)
          players_ds.where(club_id:).order(:name).map { row_to_domain(_1) }
        end

        def save(player)
          attrs = domain_to_attrs(player)
          if player.id
            players_ds.where(id: player.id).update(attrs)
            row_to_domain(players_ds.where(id: player.id).first)
          else
            new_id = players_ds.insert(attrs)
            row_to_domain(players_ds.where(id: new_id).first)
          end
        end

        private

        def players_ds
          db[:players]
        end

        def row_to_domain(row)
          Domain::Player.new(
            id: row[:id],
            name: row[:name],
            age: row[:age],
            nationality: row[:nationality],
            position: symbol_or_nil(row[:position]),
            club_id: row[:club_id],
            pace: row[:pace],
            shooting: row[:shooting],
            passing: row[:passing],
            dribbling: row[:dribbling],
            defending: row[:defending],
            physical: row[:physical],
            goalkeeping: row[:goalkeeping],
            overall: row[:overall],
            potential: row[:potential],
            form: row[:form],
            morale: symbol_or_nil(row[:morale]),
            contract_years: row[:contract_years],
            wage: row[:wage]
          )
        end

        def domain_to_attrs(player)
          {
            name: player.name,
            age: player.age,
            nationality: player.nationality,
            position: player.position&.to_s,
            club_id: player.club_id,
            pace: player.pace,
            shooting: player.shooting,
            passing: player.passing,
            dribbling: player.dribbling,
            defending: player.defending,
            physical: player.physical,
            goalkeeping: player.goalkeeping,
            overall: player.overall,
            potential: player.potential,
            form: player.form,
            morale: player.morale&.to_s,
            contract_years: player.contract_years,
            wage: player.wage
          }
        end
      end
    end
  end
end
