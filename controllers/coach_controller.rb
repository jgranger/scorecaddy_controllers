class CoachController < ApplicationController
  before_filter :authenticate_user!
  before_filter :coaches_only
  def index
    @team = Team.find(current_team.id)
    team_users = TeamUser.that_are_on_team(current_team.id)
    @players = TeamUser.that_are_on_team(current_team.id)
    @active_players = @players.where("active = ?",true)
    @inactive_players = @players.where("active = false OR active is null")
    @outstanding_invites = Invite.outstanding_for_team(current_team.id)
    @accepted_invites = Invite.claimed_for_team(current_team.id)
    @messages = current_team.messages.order("created_at DESC").limit(5)
    if browser.mobile?
      render 'index.mobile.html.erb'
    end
  end

  def create_token
    team = Team.find(current_team.id)
    if (!team.auth_token)
      team.auth_token = SecureRandom.uuid
      team.save
    end
  end

  def inactivate_player
    begin
      tu = TeamUser.find(params[:id])
      unless tu.nil?
        tu.active=false
        tu.exclude_rounds=true
        tu.save!
        return render :json => {:success=>true}
      end
    rescue Exception=>e
      logger.error e.message
    end
    render :json => {:success=>false}
  end

  def activate_player
     begin
      tu = TeamUser.find(params[:id])
      unless tu.nil?
        tu.active=true
        tu.exclude_rounds=false
        tu.save
        return render :json => {:success=>true}
      end
    rescue Exception=>e
      logger.error e.message
    end
    render :json => {:success=>false}
  end
end
