# frozen_string_literal: true

module Gaffer
  module Domain
    # Derived league standing — computed from settled results only; never persisted.
    TableRow = Struct.new(:club, :played, :won, :drawn, :lost, :gf, :ga, :points, keyword_init: true) do
      def gd
        gf.to_i - ga.to_i
      end
    end
  end
end
