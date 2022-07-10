class TeamController < ApplicationController
  include ApplicationHelper
  include RoundsHelper
  include ActionView::Helpers::DateHelper

  respond_to :json

  before_filter :on_team, :except => :associate
  before_filter :authenticate_user!
	before_filter :coaches_only, :only => :thresholds
  before_filter :coaches_only, :only => :logo_url

  def index
    @team = current_team
    round = Round.where(:team_id => current_team.id).order('round_date').first
    firstdate = round.nil? ? Date.current : (round.round_date)
    teamdays = (Date.current - firstdate.to_date)
    if teamdays < 2
      teamdays = 2
    end
    @days = [90,teamdays].min
    @courses = get_distinct_courses.map{|c|[c.name,c.id]}
    @courses.insert(0,['All Courses',0])
  end

  def day
    @day = Date.parse(params[:day])
    @day_plus = @day.to_time.advance(:days=>1).to_date
    @rounds = Round.where(:team_id => current_team.id).includes(:course).includes(:round_holes).includes(:round_holes => :round_hole_putts).where('round_date between ? and ? ',@day,@day_plus)

    if @rounds == nil or @rounds.length < 1
      redirect_to '/dashboard'
    end

    @previous = current_team.rounds.where('round_date < ?',@day).order('round_date DESC').first
    @next = current_team.rounds.where('round_date >= ?',@day_plus).order('round_date ASC').first

    @courseids = Hash.new(0)
    @rounds.each {|round| @courseids[round.course.id] += 1}
    @courseids = @courseids.sort{|a,b| a[1] <=> b[1]}.reverse!
    @courses = Hash.new(0)
    @rounds.each {|round| @courses[round.course.name + '<br /><span style="font-size:.7em;">' + round.course.tee + '</span>'] += 1}
    @coursenames = @courses.sort{|a,b| a[1] <=> b[1]}.reverse!
  end

  def customize
    logo = params[:logo_url]
    color = params[:accent_color]
    unless logo == ""
      current_team.update_attribute(:logo_url, logo)
    end
    unless color == nil
      current_team.update_attribute(:accent_color, color)
    end
  end

  def historyq
    round_limit = 1000
    if params[:limit] and Integer(params[:limit])
      round_limit = [Integer(params[:limit]),1000].min
    end
    date_from = Integer(params[:date_from])
    date_to = Integer(params[:date_to])
    player_id	 = 0
    if params[:player_id]
      player_id = Integer(params[:player_id])
    end
    course_id = Integer(params[:course_id])
    all_players = (player_id == 0)

    ateens = params[:par_type_1] != nil and params[:par_type_1] == 1
    nines = params[:par_type_2] != nil and params[:par_type_2] == 2

    practice = params[:round_type_1] != nil and params[:round_type_1] == 1
    tournament = params[:round_type_2] != nil and params[:round_type_2] == 2
    qualifying = params[:round_type_3] != nil and params[:round_type_3] == 3

    all_round_types = (practice and tournament and qualifying)
    round_types = []
    if practice
      round_types.push(1)
    end
    if tournament
      round_types.push(2)
    end
    if qualifying
      round_types.push(3)
    end
    to_date = (Time.now.to_date - date_to) + 1.day
    from_date = (Time.now.to_date - date_from) - 1.day

    logger.info to_date

    @rounds = current_team.rounds
    @rounds = @rounds.where('round_date > ? AND round_date < ?',from_date,to_date)
    @rounds = @rounds.where('rounds.season = ?',current_team.season)

    if all_players
      @rounds = @rounds.includes(:team_user).where('team_users.exclude_rounds = ?',false)
    else
      @rounds = @rounds.where('rounds.team_user_id = ?',player_id)
    end
    unless all_round_types
      @rounds = @rounds.where('round_type IN (?)',round_types)
    end
    unless nines and ateens
      if nines
        @rounds = @rounds.where('nine > 0')
      else
        @rounds = @rounds.where('nine = 0 OR nine is null')
      end
    end
    if course_id > 0
      @rounds = @rounds.where('rounds.course_id = ?',course_id)
    end
    @rounds = @rounds.order('round_date DESC').limit(round_limit)

    round_ids = @rounds.all(:select=>"rounds.id")
    logger.info round_ids.length

    rarr = []
    round_ids.each do |round|
      calcround = get_calculated_round(round)
      rarr.push(calcround)
    end

    render :json => {:rounds => rarr}
  end

  def associate
    invite = params[:invite]
    if invite and (invite.class == ''.class) # test if is not null and is string
      invite.upcase!
    end

    valid = Invite.new.can_associate? invite

    if valid
      ar_invite = Invite.by_code(invite).first

      if ar_invite
        current_team.id = ar_invite.team_id
        current_user.save
        ar_invite.claimed = true
        ar_invite.claimed_by = current_user.id
        ar_invite.claimed_on = DateTime.now
        ar_invite.save
        flash[:notice] = 'Successfully Joined Team'
        redirect_to edit_user_registration_path
        return
      end
    end

    flash[:alert] = 'Invalid Code'
    redirect_to edit_user_registration_path + '?invite=' + params[:invite]
  end

  def invalidate_team_cache_rounds
    round_ids = current_team.rounds.select('rounds.id')

    round_ids.each do |rid|
      cachekey = 'round_' + rid.id.to_s
      cachekey2 = 'round_' + rid.id.to_s + '_holes_to_par'
      logger.info cachekey
      Rails.cache.write(cachekey, nil)
      Rails.cache.write(cachekey2, nil)
    end
  end

  def thresholds
    w = params[:wedges]
    c = params[:chipping]
    l = params[:lags]

    begin
      unless w == nil or c == nil or l == nil

        t = current_team
        t.threshold_wedges = Integer(w)
        t.threshold_chipping = Integer(c)
        t.threshold_lags = Integer(l)
        t.save

        invalidate_team_cache_rounds()
      end
    rescue

    end
    redirect_to coach_path
  end

  def history
    team_users = TeamUser.that_are_on_team(current_team.id)
    q = User.joins(:team_users).where('team_users.id IN (?)',team_users)

    if !current_team_user.is_coach
      q = q.where('team_users.exclude_rounds = ?',false)
    end

    @players = q.order('team_users.user.last_name, team_users.user.first_name').map {|p| [p.short_name,p.id]}

    if !current_team_user.is_coach and current_user.exclude_rounds
      @players.insert(0,[ current_user.full_name + ' *',current_user.id])
    end

    @players.insert(0,['All Players',0])

    round = current_team.rounds.order('round_date').first
    firstdate = round.nil? ? Date.current : (round.round_date)
    teamdays = (Date.current - firstdate.to_date)
    if teamdays < 2
      teamdays = 2
    end
    @days = [90,teamdays].min
    @courses = get_distinct_courses.map{|c|[c.name,c.id]}
    @courses.insert(0,['All Courses',0])
  end

  def cancel_subscription
    @team = current_team
    if current_user.is_coach
      CancelMail.notice(current_user, @team).deliver
    end
  end

  private

  def get_distinct_courses
    Round.find_by_sql(["SELECT DISTINCT courses.name,courses.id FROM rounds INNER JOIN courses ON rounds.course_id = courses.id where rounds.team_id = ?",current_team.id])
  end
end
