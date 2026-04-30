# frozen_string_literal: true

module Gaffer
  module Repositories
    class ManagerRepository < Base
      class << self
        # Single active save slot — at most one row (dev / MVP).
        def current
          row = ds.first
          row ? row_to_domain(row) : nil
        end

        # True until the user completes name + club selection.
        def needs_onboarding?
          current.nil?
        end

        # Replace whatever was there — one manager identity per SQLite file.
        def activate!(display_name:, managed_club_id:)
          name = display_name.to_s.strip
          raise ArgumentError, "display_name blank" if name.empty?
          raise ArgumentError, "managed_club_id blank" unless managed_club_id

          db.transaction do
            ds.delete
            id = ds.insert(display_name: name, managed_club_id: managed_club_id.to_i)
            row_to_domain(ds.where(id:).first)
          end
        end

        private

        def ds
          db[:managers]
        end

        def row_to_domain(row)
          Domain::Manager.new(
            id: row[:id],
            display_name: row[:display_name],
            managed_club_id: row[:managed_club_id]
          )
        end
      end
    end
  end
end
