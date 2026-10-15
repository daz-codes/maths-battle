class StatsController < ApplicationController
  allow_unauthenticated_access

  def show
    @stats = TimesTables::Stats.new(current_player)
  end
end
