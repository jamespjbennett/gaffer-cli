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
end

task default: :test
