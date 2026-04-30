# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:leagues) do
      primary_key :id
      String :name, null: false
      Integer :year, null: false
      String :status, null: false, default: "pending"
      Integer :current_gameweek, null: false, default: 1

      index :status
      index :year
    end
  end
end
