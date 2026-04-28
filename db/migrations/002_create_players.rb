# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:players) do
      primary_key :id
      String :name, null: false
      Integer :age
      String :nationality
      String :position, null: false # gk, def, mid, att

      foreign_key :club_id, :clubs, null: false, on_delete: :restrict

      Integer :pace
      Integer :shooting
      Integer :passing
      Integer :dribbling
      Integer :defending
      Integer :physical
      Integer :goalkeeping

      Integer :overall
      Integer :potential
      Integer :form
      String :morale

      Integer :contract_years
      Integer :wage # weekly £k

      index :club_id
    end
  end
end
