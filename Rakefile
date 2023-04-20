# frozen_string_literal: true

require 'dotenv'
require 'standalone_migrations'

Dotenv.load

ENV['SCHEMA'] = File.join(ActiveRecord::Tasks::DatabaseTasks.db_dir, 'schema.rb')
StandaloneMigrations::Tasks.load_tasks

# start pipeline
task :dev do
  ruby 'bin/pipeline.rb'
end

# start pipeline with docker
task :start do
  sh 'docker compose up -d --build'
end

# debug pipeline
task :dev_debug do
  sh 'export SCHEDULE_DATE=2023-03-31 MODE=debug && ruby bin/pipeline.rb'
end

# debug pipeline with docker
task :debug do
  sh 'export SCHEDULE_DATE=2023-03-31 MODE=debug && docker compose up -d --build'
end

# stop pipeline
task :stop do
  sh 'docker compose down'
  sh 'docker rmi nhl_pipeline --force'
  sh 'docker volume rm nhl-data-pipeline_db-volume'
end

# fetch games
task :games do
  ruby 'bin/cli.rb'
end

# cli to fetch games
task :test do
  sh 'rspec'
end
