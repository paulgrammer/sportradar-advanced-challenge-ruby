# frozen_string_literal: true

# events migration file
class CreateGames < ActiveRecord::Migration[7.0]
  def change
    create_table :games do |t|
      t.string :gamePk
      t.string :season
      t.string :status
      t.jsonb  :feed
    end
  end
end
