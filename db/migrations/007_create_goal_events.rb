# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:goal_events) do
      primary_key :id
      foreign_key :fixture_id, :fixtures, null: false, on_delete: :cascade
      foreign_key :player_id, :players, null: false, on_delete: :cascade
      Integer :club_id, null: false
      String :side, null: false

      index [:fixture_id]
      index %i[fixture_id player_id]
    end
  end
end
