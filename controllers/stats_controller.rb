class StatsController < ApplicationController
  before_filter :authenticate_user!

  def index
    @rounds = current_user.rounds.recent
  end

  def testing
  end
end
