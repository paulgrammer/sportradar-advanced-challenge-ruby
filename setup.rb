# frozen_string_literal: true

ENV['ENVIRONMENT'] ||= 'development'

require 'pg'
require 'active_record'
require 'dotenv'
require 'erb'
require 'net/http'
require 'json'
require 'rufus-scheduler'
require 'yaml'
require_relative './models/game'

Dotenv.load(".env.#{ENV.fetch('ENVIRONMENT')}.local", ".env.#{ENV.fetch('ENVIRONMENT')}", '.env')

def db_configuration
  db_configuration_file_path = File.join(File.expand_path(__dir__), 'db', 'config.yml')
  db_configuration_result = ERB.new(File.read(db_configuration_file_path)).result

  YAML.safe_load(db_configuration_result, aliases: true)
end

# connect to db
begin
  ActiveRecord::Base.establish_connection(db_configuration[ENV['ENVIRONMENT']])
rescue ActiveRecord::ConnectionNotEstablished => e
  puts e.message
end
