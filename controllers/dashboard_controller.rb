class DashboardController < ApplicationController
  include RoundsHelper
  include DashboardHelper
  include ApplicationHelper
  skip_before_filter :verify_authenticity_token 
	before_filter :authenticate_user!
  before_filter :has_rounds, :except => [:select_current_team, :select_current_team]
  before_filter :has_players_on_team, :except => [:select_current_team, :select_current_team]

  def select_current_team
    @team_users = current_user.team_users.all
    @teams = []
    @team_users.each do |tu|
      @teams << Team.find(tu.team_id)
    end
  end

  def update_current_team
    team_id = params[:team_id]
    if (team_id)
      current_team_user = current_user.team_users.where(:team_id => team_id).first
      current_team_user.update_attribute(:confirmed, true) if !current_team_user.confirmed
      current_team = Team.find(current_team_user.team_id)
      session[:current_team_id] = current_team.id.to_i
      redirect_to user_home_url(current_user, current_team)
    end
  end

  def index
    #clear_current_team!
    @rounds = load_recent_team_rounds()
    @messages = current_user.messages.where('viewed = ? or viewed is null',false)
    @days = @rounds.map{|round| {:round_date=>round.round_date,
                                 :course_id=>round.course_id,
                                 :course=>round.course.name,
                                 :second_round=>round.second_round,
                                 :rounds=>[]}}.uniq.sort {|x,y| y.round_date <=> x.round_date }

    team_users = TeamUser.that_are_on_team(current_team.id)

    @players = User.joins(:team_users).where('team_users.id IN (?)',team_users.map(&:id)).where('users.exclude_rounds = ?',false).map{|player|
      {:player_id=>player.id, :name=>player.short_name, :to_par=>0, :rounds=>[]}
    }

    @rounds.each do |round|
      ix_day = @days.index{|d_round| round.round_date == d_round.round_date and round.course_id == d_round.course_id and round.second_round == d_round.second_round}
      @days[ix_day].rounds << {:round=>round,:calc_round=>get_calculated_round(round.id)}

      ix_player = @players.index{|d_player| d_player.player_id == round.team_user_id}
      unless ix_player.nil?
        c_round = get_calculated_round(round.id)
        @players[ix_player]['to_par'] = @players[ix_player].to_par + c_round.to_par
        @players[ix_player].rounds << c_round
      end
    end

    @days.each do |day|
      day.rounds.sort!{|x,y| y.calc_round.score <=> x.calc_round.score}
    end
    @players.delete_if{|player| player.rounds.count == 0}
    @players.sort!{|x,y| x.to_par <=> y.to_par}

    @players.each do |player|
      player.rounds.sort!{|x,y| x.round_date <=> y.round_date}
    end

    make_course_list()

    if browser.mobile?
      render 'index.mobile'
    end
  end

  private

  def make_course_list
    @courses = Course.team_courses_played(current_team.id).map { |course| course }
    xistingcourses = @courses.map { |c| c.id }
    xistingcourseset = Set.new xistingcourses
    mynewcourses = Course.courses_i_created_recently(current_user.id).map { |course| course }
    mynewcourses.reverse!
    mynewcourses.each do |course|
      unless xistingcourseset.include?(course.id)
        @courses.insert(0, course)
      end
    end
  end
end
