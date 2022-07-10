require "csv"
class RankController < ApplicationController
  include ApplicationHelper
  include RoundsHelper
  include RankHelper
  include ActionView::Helpers::DateHelper

  respond_to :json
  before_filter :authenticate_user!
  before_filter :on_team

  def index
    @team = current_team
    @timeframe = 'entire_season'
    if cookies[:rank_time] and ['entire_season','week_1','week_2','week_4'].include?(cookies[:rank_time])
      @timeframe = cookies[:rank_time]
    else
      flash[:notice] = 'Double clicking a button (season, 1,2, or 4 weeks) will set it as the default'
      cookies[:rank_time] = 'entire_season'
    end
    round = Round.where(:team_id => @team.id).order('round_date').first
    firstdate = round.nil? ? Date.current : (round.round_date)
    teamdays = (Date.current - firstdate.to_date)
    if teamdays < 2
      teamdays = 2
    end
    @days = [90,teamdays].min
    @courses = get_distinct_courses.map do |c|
      [c.name + ' - ' + c.tee, c.id]
    end
    @courses.insert(0,['All Courses',0])
  end

  def api
    query = RankQuery.new(params)
    player_totals = get_player_totals(query)
    render :json => {:players => player_totals.values}
  end

  def download
    query = RankQuery.new(params)
    player_totals = get_player_totals(query)
    output = CSV.generate do |csv|
      csv << ['Player', 'Rounds', 'Hole Count', 'To Par', 'Total Putts', 'Greens Missed', 'Greens Possible', 'Greens', 'Fairways Possible', 'Fairways', 'Wedges Possible', 'Wedges', 'Chipping Possible', 'Chipping', 'Lags Possible', 'Lags', 'Putting Possible', 'Putting', 'Up and Downs', 'Up and Down Opportunities', 'Three Putts', 'Penalties', 'Mojo', 'Mojo Holes', 'Birdies or Better', 'Pars or Better', 'Birdies', 'Bogeys', 'Pars', 'Double+','Putts Made 8ft and in','Putts 8ft and in','Putts Made Under 5 ft','Putts Under 5 ft','Putts Made 5-8 ft','Putts 5-8 ft','Putts Made 9-12 ft','Putts 9-12 ft']
      player_totals.values.each do |p|
        csv << [p.player_name, p.round_count_total, p.holes, p.to_par, p.total_putts, p.greens_missed, p.greens_poss, p.greens, p.fairways_poss, p.fairways, p.wedges_poss, p.wedges, p.chipping_poss, p.chipping, p.lags_poss, p.lags, p.putting_poss, p.putting, p.up_downs, p.up_down_opp, p.three_putts, p.penalties, p.mojo, p.mojo_holes, p.birdies_better, p.pars_better, p.birdies, p.bogeys, p.pars, p.doubleplus,p.puttinglte8,p.puttinglte8_poss,p.puttinglt5,p.puttinglt5_poss,p.putting5to8,p.putting5to8_poss,p.putting9to12,p.putting9to12_poss]
      end
    end
    logger.info output
    response.headers['Content-Type'] = 'text/csv'
    response.headers['Content-Disposition'] = 'attachment; filename=PlayerRankings.csv'
    render :text => output
  end

  private

  attr_accessor :round_limit
  attr_accessor :player_id
  attr_accessor :course_id
  attr_accessor :all_players
  attr_accessor :practice
  attr_accessor :tournament
  attr_accessor :qualifying
  attr_accessor :all_round_types
  attr_accessor :round_types
  attr_accessor :to_date
  attr_accessor :from_date
  attr_accessor :season
  attr_accessor :nines
end
