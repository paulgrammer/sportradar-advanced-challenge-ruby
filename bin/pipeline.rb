# frozen_string_literal: true

require_relative '../setup'

# Pipeline module
module Pipeline
  class Error < StandardError; end

  # NHL API endpoint
  NHL_API_URL = 'https://statsapi.web.nhl.com/api/v1'

  # status
  LIVE = 'Live'
  FINAL = 'Final'

  # sides
  HOME = 'home'
  AWAY = 'away'

  # holds game processes being monitored
  MONITORING = []

  class << self
    # Fetch NHL schedule
    def fetch_game_schedule
      uri = URI("#{NHL_API_URL}/schedule?date=#{ENV.fetch('SCHEDULE_DATE', Time.now.strftime('%Y-%m-%d'))}")
      response = Net::HTTP.get(uri)
      JSON.parse(response, object_class: OpenStruct)
    rescue StandardError => e
      puts e.message
    end

    # Fetch feed
    def fetch_game_feed(game_pk)
      uri = URI("#{NHL_API_URL}/game/#{game_pk}/feed/live")
      response = Net::HTTP.get(uri)
      JSON.parse(response, object_class: OpenStruct)
    end

    # Format team details and stats
    def get_team(side, feed)
      team = feed&.gameData&.teams&.dig(side)
      boxscore = feed&.liveData&.boxscore&.teams&.dig(side)
      stats = boxscore&.teamStats&.teamSkaterStats

      {
        id: team&.id,
        name: team&.name,
        goals: stats&.goals.to_i,
        hits: stats&.hits.to_i
      }
    end

    # Format feed
    def format_feed_data(feed)
      game_data = feed&.gameData
      teams = {
        home: get_team(HOME, feed),
        away: get_team(AWAY, feed)
      }

      players = game_data&.players&.table&.values&.map do |player|
        player_side = game_data&.teams&.dig(AWAY, :id) == player.currentTeam.id ? AWAY : HOME
        boxscore = feed&.liveData&.boxscore&.teams&.dig(player_side, :players, "ID#{player.id}", :stats, :skaterStats)

        {
          id: player.id,
          full_name: player.fullName,
          age: player.currentAge,
          team_id: player.currentTeam.id,
          team_name: player.currentTeam.name,
          primary_number: player.primaryNumber,
          primary_position: player.primaryPosition&.name,
          assists: boxscore&.assists.to_i,
          goals: boxscore&.goals.to_i,
          hits: boxscore&.hits.to_i,
          shots: boxscore&.shots.to_i
        }
      end

      {
        id: feed&.gamePk,
        gamePk: feed&.gamePk,
        season: game_data&.game&.season,
        status: game_data&.status&.abstractGameState,
        feed: {
          teams:,
          players:
        }
      }
    end

    # Monitor schedule
    def monitor_schedule_feed
      schedule_feed = fetch_game_schedule
      games = schedule_feed&.dates&.first&.games || []

      games.each do |game|
        process_key = "#{game.gamePk}_schedule"

        # skip those being monitored already.
        next if MONITORING.include?(process_key)

        status = game.status.abstractGameState

        # For DEBUG and TEST purposes
        if ENV['MODE'] == 'debug'
          monitor_game_feed(game.gamePk)
          next
        end

        # Monitor game if already live. don't schedule job for it.
        # or if game ended, do not watch it.
        case status
        when LIVE
          monitor_game_feed(game.gamePk)
          next
        when FINAL
          puts "Couldn't monitor game #{game.gamePk}, reason=game already ended."
          next
        end

        parsed_date = Time.parse(game.gameDate)
        puts "[SCHEDULE] Waiting for #{game.gamePk} to start at #{parsed_date.strftime('%Y/%m/%d %H:%M:%S')} timezone=#{ENV['TZ']}"

        # Add game for monitoring
        MONITORING << process_key

        # start monitoring schedule feed for game
        Rufus::Scheduler.new.every '10s', first_at: parsed_date do |job|
          feed = fetch_game_feed(game.gamePk)
          status = feed&.gameData&.status&.abstractGameState

          # Stop monitoring schedule feed when game goes live
          if status == LIVE
            job.unschedule
            MONITORING.delete(process_key)
            monitor_game_feed(game.gamePk)
          end
        end
      end
    end

    # Monitor game feed
    def monitor_game_feed(game_pk)
      process_key = "#{game_pk}_feed"

      # skip those being monitored already.
      return if MONITORING.include?(process_key)

      # Add game to those being monitored
      MONITORING << process_key

      start_time = Time.now
      # fetch feed every 5 seconds
      Rufus::Scheduler.new.every '5s' do |job|
        feed = fetch_game_feed(game_pk)
        formatted = format_feed_data(feed)
        puts "[MONITORING FEED] game=#{formatted[:gamePk]}, status=#{formatted[:status]}"

        # save feed
        Game.upsert(formatted)

        # if game ends, stop monitoring
        if formatted[:status] == FINAL
          puts "Game ended, stopped monitoring feed for #{feed[:gamePk]}"
          job.unschedule
          MONITORING.delete(process_key)
        end
      rescue StandardError => e
        puts e.message
      end

      # return start time
      { start_time: }
    end

    def run
      # Get schedule
      monitor_schedule_feed

      # Schedule game schedule updates every 30 minutes
      scheduler = Rufus::Scheduler.new
      scheduler.every '30m' do
        monitor_schedule_feed
      end

      scheduler.join
    end
  end
  # run pipeline
  run unless ENV['ENVIRONMENT'] == 'test'
end
