# frozen_string_literal: true

require "thor"

module Gaffer
  class CLI < Thor
    desc "version", "Print version"
    def version
      puts Gaffer::VERSION
    end

    default_task :version
  end
end
