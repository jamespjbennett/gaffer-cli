# frozen_string_literal: true

module Gaffer
  module Domain
    Manager = Struct.new(:id, :display_name, :managed_club_id, keyword_init: true)
  end
end
