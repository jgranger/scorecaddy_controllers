class ApiController < ApplicationController
  before_filter :authenticate_token
  before_filter :require_ssl

  include DashboardHelper
  include RoundsHelper
  include ApplicationHelper
  respond_to :json

  def team_info
    render :json => {
      success: true,
      reason: "",
      team: {
        school_name: @token_team[:school_name],
        team_name: @token_team[:team_name],

        message: @token_team[:message],
        season: @token_team[:season],

        threshold_chipping: @token_team[:threshold_chipping],
        threshold_wedges: @token_team[:threshold_wedges],
        threshold_lags: @token_team[:threshold_lags]
      }
    }
  end

  def list_players
    players = User.where(team_id: @token_team.id).map{ |player| {
        id: player[:id],
        team_id: player[:team_id],
        active: player[:active],
        email: player[:email],
        first_name: player[:first_name],
        last_name: player[:last_name],
        coach: player[:is_coach],
        phone: player[:phone_number],
        exclude_rounds: player[:exclude_rounds]
    }}
    render :json => {
      success: true,
      reason: "",
      players: players.as_json
    }
  end
  def player_rounds
    player_id = params[:id]
    if player_id.nil?
      render :json => {
        success: false,
        reason: "missing parameter 'id'"
      }, :status => 404
      return
    end

    round_ids = Round
      .where(team_user_id: player_id)
      .where(team_id: @token_team.id)
      .map{|round| round.id}

    render :json => {
      success: true,
      reason: "",
      rounds: round_ids.as_json
    }
  end

  def list_courses
    courses = Course.all.map { |course| {
      id: course[:id],
      name: course[:name],
      active: course[:active],
      country: course[:country],
      created_by: course[:created_by],
      modified_by: course[:modified_by],
      par: course[:par],
      tee: course[:tee],
      yards: course[:yards],
      holes: course.holes.map { |hole| {
        course_id: hole[:course_id],
        hole_number: hole[:hole_number],
        yards: hole[:yards],
        par: hole[:par]
      }},
      rounds: course.rounds.where(team_id: @token_team.id).map {
        |round| round.id
      }
    }}
    render :json => {
      success: true,
      reason: "",
      courses: courses
    }
  end
  def list_team_courses
    courses = TeamCourse.where(team_id: @token_team.id).all
    render :json => {
      success: true,
      reason: "",
      courses: courses.as_json
    }
  end
  def create_course
    params[:course][:holes_attributes] ||= params[:course][:holes]
    params[:course][:holes_attributes].each { |i, hole|
      hole[:hole_number] = i
    }

    @course = Course.new(params[:course].except :holes)
    team_user = TeamUser.where(team_id: @token_team.id).first
    @course.created_by = team_user.id
  	@course.modified_by = team_user.id

    existing = TeamCourse
                .where(:team_id => @token_team.id)
                .where(:course_id => @course.id)
                .first

    unless existing
      exists = TeamCourse.new(
        :team_id => @token_team.id,
        :course_id => @course.id
      ).save
      unless exists
        render :json => {
          success: false,
          reason: "Failed to associate course with team"
        }, :status => 400
      end
    end

    if !@course.save
      render :json => {
        success: false,
        reason: "Failed to save course: " + @course.errors.full_messages.to_s
      }, :status => 400
      logger.error(@course.errors.full_messages)
    else
      render :json => {
        success: true,
        reason: "",
        course_id: @course.id
      }
    end
  end

  def list_rounds
    @rounds = Round.dash_recent(@token_team).all.map { |round| {
      :round_date => round.round_date,
      :course_id  => round.course_id,
      :course     => round.course.name,
      :player     => round.team_user.user.short_name,
      :player_id  => round.team_user_id,
      :score      => round.score,
      :round_type => round.round_type,
      :round_id   => round.id
    }}
    render :json => {
      success: true,
      reason: "",
      rounds: @rounds.as_json
    }
  end
  def round_info
    round_id = params[:id]
    if round_id.nil?
      render :json => {
        success: false,
        reason: "missing parameter 'id'"
      }, :status => 404
      return
    end

    round = Round
      .includes(:round_holes)
      .includes(:round_holes => :round_hole_putts)
      .find_by_id(round_id)

    if round.nil? or round.team_id != @token_team.id
      render :json => {
        success: false,
        reason: "invalid round"
      }, :status => 404
      return
    end

    round.round_holes.each { |round_hole|
      round_hole.extra_shot ||= false
      round_hole.extra_chip ||= false
      round_hole.round_hole_putts.delete_if {|x| x.distance_in_ft.nil? }
    }

    round = round.as_json(
      include: {
        round_holes: {
          include: :round_hole_putts
        }
      }
    ).round

    round.delete 'created_at'
    round.delete 'updated_at'

    render :json => {
      success: true,
      reason: "",
      round: round
    }
  end
  def create_round
    @round = Round.new(params[:round])
    team_user = TeamUser.where(id: params[:team_user_id]).where(team_id: @token_team.id).first
    @round.user_id = team_user.user_id
    @round.team_user_id = team_user.id

    if !params[:round][:round_date_formatted]
      @round.round_date = 12.hours.ago
    end

    if !params[:round][:course_id]
      render :json => {
        success: false,
        reason: "No course id"
      }, :status => 404
    end

    @round.team_id = @token_team.id
    @round.season = @token_team.season
    if !@round.save
      render :json => {
        success: false,
        reason: "Failed to save round" + @round.errors.full_messages.to_s
      }, :status => 400
      logger.error(@round.errors.full_messages)
    else
      render :json => {
        success: true,
        reason: "",
        round_id: @round.id
      }
    end
  end

  private
    def authenticate_token
      @token_team = Team.where(auth_token: params[:token] || "").first
      if @token_team.nil?
        render :json => {
          success: false,
          reason: "invalid token"
        }, :status => 404
      end
    end
end
