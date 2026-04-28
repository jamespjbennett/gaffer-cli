# frozen_string_literal: true

require "fileutils"
require "sequel"

Sequel.extension :migration

module Gaffer
  module Database
    class Error < StandardError; end

    class << self
      attr_accessor :connection

      def db
        raise Error, "Database not connected. Call Gaffer::Database.connect first." unless connection

        connection
      end

      def connect(url = nil)
        self.connection = Sequel.connect(url || default_url)
        connection
      end

      def disconnect
        connection&.disconnect
        self.connection = nil
      end

      def migrate(target: nil)
        ensure_connection
        opts = { allow_missing_migration_files: true }
        opts[:target] = target unless target.nil?
        Sequel::Migrator.run(connection, migrations_path, **opts)
      end

      def migrations_path
        File.expand_path("../../db/migrations", __dir__)
      end

      private

      def ensure_connection
        connect unless connection
      end

      def default_url
        path = ENV.fetch("GAFFER_DB_PATH") { File.expand_path("../../db/gaffer.sqlite", __dir__) }
        FileUtils.mkdir_p(File.dirname(path))
        "sqlite://#{path}"
      end
    end
  end
end
