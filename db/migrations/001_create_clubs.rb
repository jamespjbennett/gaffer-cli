# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:clubs) do
      primary_key :id
      String :name, null: false
      String :short_name, null: false
      Integer :league_id
      Integer :reputation, null: false, default: 50
      Integer :budget, null: false, default: 0
      Integer :wage_budget, null: false, default: 0
      String :stadium
      String :chairman_name
      String :chairman_mood
      String :board_target

      index :league_id
    end
  end
end
