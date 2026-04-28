# frozen_string_literal: true

module Gaffer
  module Repositories
    class Base
      class << self
        private

        def db
          Gaffer::Database.db
        end

        def symbol_or_nil(value)
          return nil if value.nil? || value.to_s.strip.empty?

          value.to_sym
        end
      end
    end
  end
end
