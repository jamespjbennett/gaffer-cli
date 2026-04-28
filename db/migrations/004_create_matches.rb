# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:matches) do
      primary_key :id

      foreign_key :fixture_id, :fixtures, null: false, unique: true, on_delete: :cascade

      Integer :home_score, null: false, default: 0
      Integer :away_score, null: false, default: 0
      Integer :home_possession # percentage for home side
      Integer :home_shots
      Integer :home_shots_ot
      Integer :away_shots
      Integer :away_shots_ot

      # JSON payloads stored as text (array / object literals)
      String :events, text: true, default: "[]"
      String :player_ratings, text: true, default: "{}"
      String :narrative, text: true
    end
  end
end
