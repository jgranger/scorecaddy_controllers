class PlayerController < ApplicationController
  include ApplicationHelper
  include RoundsHelper
  include PlayerHelper
  include ActionView::Helpers::DateHelper
  before_filter :authenticate_user!

  def index
    setup_time_frame
    set_days_for_time_slider
    setup_courses_for_drop_down_list
  end

  def show
    if ensure_player_data_secure(params)
      load_header_filter_data
      @team_user = TeamUser.find(params[:id])
      @user = User.find(@team_user.user_id)
    else
      redirect_to players_url
    end
  end

  def api
    if ensure_player_data_secure(params)
      query = PlayerQuery.new(params)
      render :json => {:rounds => get_rounds(query)}
    else
      render :json => {:error => 'unauthorized'}
    end
  end

  private

  def set_days_for_time_slider()
    round = Round.where(:team_id => current_team.id).where('rounds.season = ?', current_team.season).order('round_date').first
    firstdate = round.nil? ? Date.current : (round.round_date)
    team_days = (Date.current - firstdate.to_date)
    if team_days < 2
      team_days = 2
    end
    @days = [90, team_days].min
  end

  def rank_time_cookie_set?
    cookies[:rank_time] and ['entire_season', 'week_1', 'week_2', 'week_4'].include?(cookies[:rank_time])
  end

  def setup_courses_for_drop_down_list
    @courses = get_distinct_courses.map do |c|
      [c.name + ' - ' + c.tee, c.id]
    end
    @courses.insert(0, ['All Courses', 0])
  end

  def setup_time_frame
    @timeframe = 'entire_season'
    if rank_time_cookie_set?
      @timeframe = cookies[:rank_time]
    else
      flash[:notice] = 'Double clicking a button (season, 1,2, or 4 weeks) will set it as the default'
      cookies[:rank_time] = 'entire_season'
    end
  end

  def load_header_filter_data
    setup_time_frame

    user_query = TeamUser.that_are_on_team(current_team.id)
 
    if current_team_user.is_coach
      user_query = user_query.where('team_users.exclude_rounds = ? OR team_users.id = ?', false, params[:id])
    else
      user_query = user_query.where('team_users.exclude_rounds = ?', false)
    end

    user_query = user_query.order('team_users.last_name,team_users.first_name')

    @players = user_query.map { |p| {:pid=>p.id, :name=>p.user.short_name} }

    round = Round.where(:team_id => current_team.id).where('season = ?', current_team.season).order('round_date').first
    firstdate = round.nil? ? Date.current : (round.round_date)
    teamdays = (Date.current - firstdate.to_date)
    if teamdays < 2
      teamdays = 2
    end
    @days = [365, teamdays].min
    @courses = get_distinct_courses.map { |c| [c.name, c.id] }
    @courses.insert(0, ['All Courses', 0])
  end

  def get_distinct_courses
    Round.find_by_sql(["SELECT DISTINCT courses.name,courses.tee,courses.id FROM rounds INNER JOIN courses ON rounds.course_id = courses.id where rounds.team_id = ?", current_team.id])
  end
end
