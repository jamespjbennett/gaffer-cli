# frozen_string_literal: true

module Gaffer
  module Ui
    # Preset XI validation for dugout — headless/tests short-circuit.
    module DugoutLineupPreset
      module_function

      # @return [Array<Player>, nil] canonical XI rows or nil if preset invalid/absent
      def validate_lineup(preset, squad)
        return nil if preset.nil?

        list = preset.is_a?(Array) ? preset : nil
        return nil unless list && list.size == 11

        allowed_ids = squad.each_with_object({}) { |pl, acc| acc[pl.id] = true }
        seen = {}

        list.map do |maybe|
          return nil unless maybe.respond_to?(:id)

          id = maybe.id
          return nil unless allowed_ids[id]
          return nil if seen[id]

          seen[id] = true
          squad.find { |s| s.id == id }
        end
      end
    end
  end
end
