# frozen_string_literal: true

# Games model class
class Game < ActiveRecord::Base
  validates :gamePk, uniqueness: true
end
