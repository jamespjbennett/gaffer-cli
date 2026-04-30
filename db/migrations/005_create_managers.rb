# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:managers) do
      primary_key :id
      String :display_name, null: false
      Integer :managed_club_id, null: false # references clubs(id)

      index :managed_club_id
    end
  end
end
