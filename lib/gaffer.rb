# frozen_string_literal: true

require_relative "gaffer/version"

module Gaffer
end

require_relative "gaffer/database"
require_relative "gaffer/domain/club"
require_relative "gaffer/domain/player"
require_relative "gaffer/domain/manager"
require_relative "gaffer/domain/fixture"
require_relative "gaffer/domain/match"
require_relative "gaffer/domain/match_result"
require_relative "gaffer/domain/match_engine"
require_relative "gaffer/repositories/base"
require_relative "gaffer/repositories/club_repository"
require_relative "gaffer/repositories/player_repository"
require_relative "gaffer/repositories/manager_repository"
require_relative "gaffer/repositories/fixture_repository"
require_relative "gaffer/repositories/match_repository"
require_relative "gaffer/commands/play_match"
