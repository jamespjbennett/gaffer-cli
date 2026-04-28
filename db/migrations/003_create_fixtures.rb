# frozen_string_literal: true

# Matches reference fixtures; Fixture rows exist before a Match row is stored.
Sequel.migration do
  change do
    create_table(:fixtures) do
      primary_key :id
      Integer :season_id
      Integer :gameweek, null: false

      foreign_key :home_club_id, :clubs, null: false, on_delete: :restrict
      foreign_key :away_club_id, :clubs, null: false, on_delete: :restrict

      TrueClass :played, default: false

      index %i[season_id gameweek]
    end
  end
end
