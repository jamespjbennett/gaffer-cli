# frozen_string_literal: true

require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

namespace :db do
  desc "Apply pending Sequel migrations"
  task :migrate do
    $LOAD_PATH.unshift("#{__dir__}/lib")
    require "gaffer/database"
    Gaffer::Database.migrate
    puts "Migrations applied to #{Gaffer::Database.connection.opts[:database]}"
  end

  desc "Load five fictional clubs (tiered quality). Runs db:migrate first."
  task seed: :migrate do
    $LOAD_PATH.unshift("#{__dir__}/lib")
    require "bundler/setup"
    require "gaffer"
    load File.expand_path("db/seeds/fictional_five_teams.rb", __dir__)
  end
end

desc "IRB shell with Bundler, Gaffer, and DB loaded (same as: bin/gaffer console)"
task :console do
  $LOAD_PATH.unshift("#{__dir__}/lib")
  require "bundler/setup"
  require "gaffer"
  require "gaffer/console"
  Gaffer::Console.start
end

task default: :test
