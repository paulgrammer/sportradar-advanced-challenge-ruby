# frozen_string_literal: true

require_relative '../setup'

game_id = ENV['game_id']
season = ENV['season']

begin
  data = if game_id
           Game.find(game_id)
         elsif season
           Game.find_by(season:)
         else
           Game.all
         end

  puts data.as_json
rescue ActiveRecord::RecordNotFound => e
  puts e.message
end
