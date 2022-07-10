class ApplicationController < ActionController::Base
  protect_from_forgery
  before_filter :ensure_domain
  before_filter :set_current_team
  before_filter :set_current_team_user if :valid_session
  before_filter :notice_if_not_on_team
  before_filter :require_ssl
  before_filter :set_cache_buster

  def valid_session
    return session[:current_team_id].nil?
  end

  def set_current_team
    team = Team.where(:id => session[:current_team_id]).first if session[:current_team_id]
    if team
      @current_team = team
    end
  end

  def current_team
    team = Team.where(:id => session[:current_team_id]).first if session[:current_team_id]
    if team
      @current_team = team
    else
      @current_team = nil
    end
  end

  def current_team_user
    team_user = TeamUser.where(:team_id => @current_team).where(:user_id => current_user.id).first
    if team_user
      @current_team_user = team_user
    else
      @current_team_user = nil
    end
  end

  def set_current_team_user
    @team_user = TeamUser.where(:team_id => session[:current_team_id]).where(:user_id => current_user.id).first if session[:current_team_id]
    if @team_user
      @current_team_user = @team_user
    end
  end

  def clear_current_team!
    @current_team = nil
    session[:current_team_id] = nil
  end

  def set_cache_buster
    response.headers["Cache-Control"] = "no-cache, no-store, max-age=0, must-revalidate"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "Fri, 01 Jan 1990 00:00:00 GMT"
  end

  APP_DOMAIN = 'secure.scorecaddy.com'

  def ensure_domain
    if Rails.env == 'production' && request && (request.subdomains.first != "secure")
      redirect_to "http://scorecaddy.com", :status => 301 and return
    end
  end

  def has_rounds
    if current_team_user.nil?
      @has_rounds = true
    else
      if current_team_user.is_coach
        @has_rounds = true
      else        
        @has_rounds = current_team_user.user.rounds.length > 0
      end
    end

  end

  def has_players_on_team
    if @current_team
      if current_team_user.is_coach
        @players_on_team = TeamUser.that_are_on_team(@current_team.id).count > 1
      else
        @players_on_team = true
      end
    end
  end

  rescue_from ActionView::MissingTemplate do |exception|
    # use exception.path to extract the path information
    # This does not work for partials
    if user_signed_in?
      pp '>>>>>>>>> missing template - redirecting <<<<<<<<<<<'
      redirect_to '/dashboard'
    else
      redirect_to '/users/signin'
    end
  end

  def is_admin
    unless current_user and current_user.admin
      redirect_to new_user_session_path
    end
  end

  def on_team
    unless current_user and current_team.id and current_team.id > 0
      redirect_to dashboard_index_path
    end
  end

	def coaches_only
    unless current_user and current_team.id and current_team.id > 0 and current_team_user.is_coach
      flash[:notice] = 'Coaches Only'
      redirect_to dashboard_index_path
    end
	end

  layout :layout_by_resource
  
  def layout_by_resource
    browser = Browser.new(request.env["HTTP_USER_AGENT"])
    if user_signed_in?
      if browser.mobile?
        if params[:controller] == "rounds" && params[:action] == "new"
          "application.mobile.form"
        elsif params[:controller] == "rounds" && params[:action] == "edit"
          "application.mobile.form"
        elsif params[:controller] == "payment"
          "application"
        else
          "application.mobile"
        end
      else
        "application"
      end
    else
       if browser.mobile?
        "application.mobile"
       elsif params[:controller] == "sessions"
        "application"
       else
        "public"
      end
    end
  end

  def after_sign_in_path_for(resource_or_scope)
    if resource_or_scope.is_a?(User)
     # "/"
     "/dashboard/select_current_team"
    else
      super
    end
  end

  def after_sign_out_path_for(resource_or_scope)
    if request.url.include?('dev')
      "http://scorecaddy.development"
    elsif request.url.include?('staging')
      "https://scorecaddy-staging.herokuapp.com"
    else
       "https://secure.scorecaddy.com"
    end
  end

  def user_home_url(user, team)
    send_user_to = new_user_session_url               unless user.present?
    send_user_to ||= admin_dashboard_url              if user && user.admin && team.nil?
    send_user_to ||= team_redirect(user, team)  if team.present?
    send_user_to ||= select_current_team_url
    send_user_to
  end

  def team_redirect(user, team)
    return dashboard_url  if user.admin
    return dashboard_url
    return nil
  end

  private

  def notice_if_not_on_team
    if false
      if current_user != nil and (session[:current_team_id] == nil or session[:current_team_id] < 1)
        flash[:alert] = "<a href='" + edit_user_registration_path + "?invite=' style='color:#205791;'>Click Here to associate with your team.</a><br />If you do not have an invite code, your coach can provide one for you."
      end
    end
  end

  def require_ssl
    unless request.url.include?('dev') || request.url.include?('staging')
      unless (request.ssl? || request.port == 443)
        redirect_to "https://secure.scorecaddy.com" + request.fullpath
      end
    end
  end
end
