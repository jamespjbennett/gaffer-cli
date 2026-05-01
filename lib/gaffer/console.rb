# frozen_string_literal: true

require "irb"
require "irb/completion"

module Gaffer
  module Console
    module_function

    # Starts IRB with the default SQLite DB (GAFFER_DB_PATH / db/gaffer.sqlite)
    # or an explicit Sequel URL (e.g. sqlite://tmp/dev.sqlite).
    def start(database_url = nil)
      Gaffer::Database.prepare(database_url)

      define_helpers!
      $stderr.puts intro
      ARGV.clear
      IRB.start(__FILE__)
    end

    def define_helpers!
      Object.define_method(:db) { Gaffer::Database.db } unless Object.method_defined?(:db, false)
    end

    def intro # :nodoc:
      conn = Gaffer::Database.connection
      line =
        if conn.respond_to?(:url)
          "Database URL: #{conn.url}"
        elsif (path = conn.opts[:database])
          "Database path: #{path}"
        else
          "Database: #{conn.inspect}"
        end

      <<~TXT
        Gaffer #{Gaffer::VERSION}
        #{line}

        Tip: `db` is Sequel (`db.tables`, db[:clubs], …). Repos in Gaffer::Repositories::*.

      TXT
    end
  end
end
