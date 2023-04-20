# frozen_string_literal: true

ENV['ENVIRONMENT'] = 'test'
require_relative '../bin/pipeline'

RSpec.describe 'Pipeline' do
  let(:game_pk) { 2_022_021_189 }

  after(:all) do
    Game.destroy_all
  end

  describe 'fetch_game_schedule' do
    it 'Returns a list of data about the schedule for a specified date range.' do
      schedule_data = Pipeline.fetch_game_schedule
      expect(schedule_data).to respond_to(:dates)
    end
  end

  describe 'fetch_game_feed' do
    it 'Returns all data about a specified game id.' do
      feed = Pipeline.fetch_game_feed(game_pk)
      expect(feed.gamePk).to eq(game_pk)
    end
  end

  describe 'format_feed_data' do
    it 'Returns ingested feed data for saving to database' do
      feed = Pipeline.fetch_game_feed(game_pk)
      formatted = Pipeline.format_feed_data(feed)
      expect(feed.gamePk).to eq(formatted[:gamePk])
    end
  end

  describe 'monitor_game_feed' do
    it 'Monitors game feed at an interval of 5 seconds until it ends and saves in DB' do
      monitor = Pipeline.monitor_game_feed(game_pk)
      start_time = monitor[:start_time]

      # confirm that feed is watched every after 5 seconds
      sleep 5
      expect(Time.now - start_time).to be_within(0.1).of(5)

      # confirm game has been saved in DB
      sleep 3
      expect(Game.exists?(game_pk)).to be_truthy
    end
  end
end
