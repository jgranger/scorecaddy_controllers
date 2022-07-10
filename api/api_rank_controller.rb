class ApiRankController < ApplicationController
  include DashboardHelper
  include RoundsHelper
  include ApplicationHelper
  include RankHelper

  before_filter :require_ssl
  before_filter :authenticate_user!

  respond_to :json

  def all
    query = RankQuery.new(params)
    player_totals = get_player_totals(query)
    render :json => player_totals.values.as_json
  end
end