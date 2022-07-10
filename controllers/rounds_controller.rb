require "browser"
class RoundsController < ApplicationController
  include RoundsHelper
  include ApplicationHelper
  before_filter :authenticate_user!
  before_filter :redirect_if_not_on_team

  def index
    @team = true
    if cookies[:rfilter].nil? or cookies[:rfilter] == 'team'
      _rounds = Round.team_recent(current_team.id)
    else
      _rounds = Round.player_recent(current_team.id, current_team_user.id).where('season = ?',current_team.season).where(:team_id => current_team.id)
      @team = false
    end
    @rounds = _rounds.map{|round| {:round=>round,:calc_round=>get_calculated_round(round.id)}}
		@courses = Course.team_courses_played(current_team.id).map{|course| course }
    @current_team_user = current_team_user
    xistingcourses = @courses.map{|c| c.id }
    xistingcourseset = Set.new xistingcourses

    mynewcourses = Course.courses_i_created_recently(current_user.id).map{|course| course }
    mynewcourses.reverse!
    mynewcourses.each do |course|
      unless xistingcourseset.include?(course.id)
        @courses.insert(0,course)
      end
    end

    if browser.mobile?
      render 'index.mobile'
    end
  end

  def show
    @round = Round.where(id: params[:id]).includes([:course, :round_holes, :round_hole_putts]).first
    unless(@round.user_id == current_user.id or @round.team_id == current_team.id )
      redirect_to rounds_path
    end

    @putting_breakdown = putting_breakdown(@round)
    @chipping_breakdown = chipping_breakdown(@round)
    @leaderboard = leaderboard(@round)
    @missed_putts = missed_putts(@round)
    @made_putts_total_distance = made_putts_total_distance(@round)
    @avg_putt_distance = "%5.1f" % chip_putt_distance(@round)
    if @round.round_holes.length > 0 and !@made_putts_total_distance.nil?
      avg_putt_made_num = Float(@made_putts_total_distance)/Float(@round.round_holes.length)
      @avg_made_putt_length = format("%.1f",avg_putt_made_num)
    else
      @avg_made_putt_length = '-'
    end
    @wedges = wedges(@round)
    @next = Round.next(@round.round_date,@round.team_user_id,@round.id).first
    @previous = Round.previous(@round.round_date,@round.team_user_id,@round.id).first

    if browser.mobile?
      render 'show.mobile'
    end
  end

  def new
    @course = Course.where(id: params[:id]).includes(:holes).order("holes.hole_number").first
    @holes = Hole.where(course_id: @course)

    @nine = 0

    if params[:nine]
      if params[:nine] == 'front'
        @nine = 1
      elsif params[:nine] == 'back'
        @nine = 2
      end
    end

    if current_team_user.is_coach
      team_users = TeamUser.that_are_on_team(current_team.id)
      @players = team_users.map{|tu|[tu.user.short_name, tu.id]}
    end

    @round = Round.new
    @round.course_id = @course
    @round.round_date = 12.hours.ago
    @round.team_user_id = current_team_user.id

    @holes.each_with_index do |hole,ix|
    	h = @round.round_holes.build
    	h.hole = hole.hole_number
    	h.yards = hole.yards
    	h.par = hole.par
      4.times do |pix|
        p = h.round_hole_putts.build
        p.putt_number = pix+1
      end
    end

  end

  # GET /rounds/1/edit
  def edit
    @round = Round.find(params[:id], :include => [:course,:round_holes,{:round_holes=>:round_hole_putts}],:order=>'round_holes.hole ASC, round_hole_putts.putt_number ASC')
    @nine = (@round.nine or 0)
    if current_team_user.is_coach
      team_users = TeamUser.that_are_on_team(current_team.id)
    @players = TeamUser.where('team_users.id IN (?)', team_users).map{|tu|[tu.user.short_name, tu.id]}
      @players.insert(0,[current_user.short_name,current_team_user.id])
    end
    if(current_team_user.is_coach or current_user.id == @round.team_user_id)
      @course = @round.course
      @edit = true
    else
      redirect_to rounds_path
    end
  end

  # POST /rounds
  def create
    #todo - permit
    permitted_params = ActiveSupport::HashWithIndifferentAccess.new(params[:round])
    @round = Round.new(permitted_params)
    if current_team_user.is_coach and params[:team_user_id]
      team_user = TeamUser.where(id: params[:team_user_id]).first
      @round.user_id = team_user.user_id
      @round.team_user_id = team_user.id
    else
      @round.user_id = current_user.id
      @round.team_user_id = current_team_user.id
    end
    @round.team_id = current_team.id
    @round.season = current_team.season
    @round.valid?
    logger.error(@round.errors.full_messages)
    if @round.save!
      redirect_to(round_path(@round), :notice => 'Round was successfully created.')
    else
      @nine = (@round.nine or 0)

  	  @course = Course.where(id: params[:id]).includes(:holes).order("holes.hole_number").first
      render :action => "new"
    end
  end

  # PUT /rounds/1
  def update
    @round = Round.find(params[:id])

    if(current_team_user.is_coach or current_user.id == @round.team_user_id)
      if @round.update_attributes(params[:round])
        invalidate_cache_rounds()
        redirect_to(round_path(@round), :notice => 'Round was successfully updated.')
      else
        render :action => "edit"
      end
    else
      flash[:alert] = 'You do not have permission to edit this round'
    end
  end

  # DELETE /rounds/1
  def destroy
    @round = Round.find(params[:id])
    if(current_team_user.is_coach or current_user.id == @round.team_user_id)
      @round.destroy
    else
      flash[:alert] = 'You do not have permission to delete this round'
    end
    redirect_to(rounds_url)
  end

  def report
    r = Round.find(params[:id])
    unless(r.user_id == current_user.id or r.team_id == current_team.id )
      redirect_to rounds_path
    end

    @round = Round.find(params[:id], :include => [:course,:round_holes,{:round_holes=>:round_hole_putts}],:order=>'round_holes.hole ASC, round_hole_putts.putt_number ASC')
    @putting_breakdown    = putting_breakdown(@round)
    @chipping_breakdown   = chipping_breakdown(@round)
    @leaderboard          = leaderboard(@round)
    @missed_putts         = missed_putts(@round)
    @wedges               = wedges(@round)
    report = RoundReport.new
    report.user = current_user
    report.round = @round
    report.putting_breakdown = @putting_breakdown
    report.chipping_breakdown = @chipping_breakdown
    report.leaderboard = @leaderboard
    report.missed_putts = @missed_putts
    report.wedges = @wedges
    report.team  = current_team
    output = report.to_pdf
    send_data output, :filename => "round.pdf", :type => "application/pdf"
  end

  def publish
    @round = Round.find(params[:id])
    @round.share_token = SecureRandom.uuid
    @round.save!
    redirect_to :back
  end

private

  def invalidate_cache_rounds
    Rails.cache.write('round_' + @round.id.to_s + '_holes_to_par', nil)
    Rails.cache.write('round_' + @round.id.to_s, nil)
  end

  def redirect_if_not_on_team
    if current_user != nil and (current_team.id == nil or current_team.id < 1)
      redirect_to '/'
    end
  end

  def chipping_breakdown(round)
    rv = []
    round.round_holes.each do |hole|
      if hole.is_up_down_attempt?
        first_putt = hole.round_hole_putts.sort_by{|p| p.putt_number }.first
        rv.push({:hole=>hole.hole,:chip_yds=>(hole.chip_yards.nil? ? 0 : hole.chip_yards),:left=>(first_putt != nil ? first_putt.distance_in_ft : 0),:updown=>(hole.up_and_down or (hole.putts == nil or hole.putts == 0))})
      end
    end
    rv
  end

  def putting_breakdown(round)
    lt5_m = 0
    lte8_m = 0
    lte12_m = 0
    lte15_m = 0
    lte20_m = 0
    lte30_m = 0
    gt30_m = 0

    lt5 = 0
    lte8 = 0
    lte12 = 0
    lte15 = 0
    lte20 = 0
    lte30 = 0
    gt30 = 0
    round.round_hole_putts.each do |p|
      if p.distance_in_ft != nil
        if p.distance_in_ft < 5
          lt5 += 1
          if p.holed
            lt5_m +=1
          end
        elsif p.distance_in_ft <=8
          lte8+=1
          if p.holed
            lte8_m +=1
          end
        elsif p.distance_in_ft <=12
          lte12+=1
          if p.holed
            lte12_m +=1
          end
        elsif p.distance_in_ft <=15
          lte15+=1
          if p.holed
            lte15_m +=1
          end
        elsif p.distance_in_ft <=20
          lte20+=1
          if p.holed
            lte20_m +=1
          end
        elsif p.distance_in_ft <=30
          lte30+=1
          if p.holed
            lte30_m +=1
          end
        else
          gt30+=1
          if p.holed
            gt30_m +=1
          end
        end
      end
    end
      # returns  array for each bucket
      # made putts, attempted putts, and missed putts
      {'lt5'=>[lt5_m,lt5,(lt5-lt5_m)],
       'lte8'=>[lte8_m,lte8,(lte8-lte8_m)],
       'lte12'=>[lte12_m,lte12,(lte12-lte12_m)],
       'lte15'=>[lte15_m,lte15,(lte15-lte15_m)],
       'lte20'=>[lte20_m,lte20,(lte20-lte20_m)],
       'lte30'=>[lte30_m,lte30,(lte30-lte30_m)],
       'gt30'=>[gt30_m,gt30,(gt30-gt30_m)]}
  end

  def leaderboard(round)
    rv = []
    to_par = 0
    round.round_holes.each do |hole|
      x = hole.score - hole.par
      to_par += x
      rv.push({:hole=>hole.hole.to_s,:running_total=>format_to_par(to_par),:running_total_number=>to_par,:this_hole=>format_to_par(x), :this_hole_num=>x,:score=>hole.score.to_s,:par=>hole.par.to_s})
    end
    rv
  end

  def format_dash_zero(number)
    if number == 0
      '-'
    else
      number.to_s
    end
  end
  def format_to_par(number)
    if number == 0
      '-'
    elsif number < 0
      number.to_s
    else
      '+' + number.to_s
    end
  end

  def made_putts_total_distance(round)
    rv = 0
    round.round_holes.each do |hole|
      hole.round_hole_putts.each do |putt|
        if putt.holed or putt.distance_in_ft.nil?
          rv += putt.distance_in_ft || 0
        end
      end
    end
    rv
  end

  def missed_putts(round)
    rv = []
    round.round_holes.each do |hole|
      x = nil
      hole.round_hole_putts.sort_by {|a| a.putt_number}.each do |putt|
        unless x == nil
          x[:distance_left] = putt.distance_in_ft
          rv.push(x)
          x = nil
        end
        if putt.holed or putt.distance_in_ft == nil
          break
        elsif putt.distance_in_ft > 15
          x = {:hole=>hole.hole.to_s,:putt_distance=>putt.distance_in_ft,:putt_number=>putt.putt_number}
        end
      end
    end
    rv
  end

  def wedges(round)
    rv = []
    round.round_holes.each do |hole|
      if hole.approach_yards != nil and hole.approach_yards <= 131
        putt = hole.round_hole_putts.sort_by {|a| a.putt_number}.first
        green = hole.approach == 'G'
        distance = (green && putt) ? putt.distance_in_ft : 0
        rv.push({:hole_number=>hole.hole, :approach_distance=>hole.approach_yards, :green=>green, :putt_distance=>distance})
      end
    end
    rv
  end
end
