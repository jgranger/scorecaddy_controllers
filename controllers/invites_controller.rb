class InvitesController < ApplicationController
  before_filter :authenticate_user!
  before_filter :coaches_only  
	
  def index
    @invites = Invite.all
  end

  # GET /invites/new.xml
  def new
  
  end

  # GET /invites/1/edit
  def edit
    @invite = Invite.find(params[:id])
  end

  # POST /invites
  # POST /invites.xml
  def create
  	to_email = request.params[:email]
    user = User.where('lower(email) = ?',to_email.downcase).first
    unless user
      # if email is valid
      invite = Invite.new
      invite.to = to_email
      invite.team_id = current_team.id
      invite.created_by = current_user.id
      invite.claimed = false

      begin
        if invite.save!
          flash[:notice] = 'Created Invitation for ' + to_email
          uri = "#{request.protocol}#{request.host_with_port}" 
          TeamMail.invite(current_user.full_name + ' ' + current_user.email ,to_email, invite.invite, current_team.team_name,false, uri).deliver
        else
          flash[:alert] = 'Error Creating Invitation, check the email address and try again.'
        end
      rescue Exception => ex
        
      end
      redirect_to coach_path
    else
      begin
        existing_team_user = TeamUser.where(:team_id => current_team.id).where(:user_id => user.id).first
        unless existing_team_user
          team_user = TeamUser.new
          team_user.user_id = user.id
          team_user.team_id = current_team.id
          team_user.save
          flash[:notice] = 'User added to ' + current_team.team_name
          uri = "#{request.protocol}#{request.host_with_port}" 
          AddCurrentUserToTeamMail.invite('golf@scorecaddy.com', to_email,current_team.team_name,false, uri).deliver
        else
          flash[:notice] = 'User already is part of this team'
        end
        redirect_to admin_invites_path
      rescue 
        flash[:alert] = 'Error Creating Invitation.'
        redirect_to admin_invite_coach_path
      end
    end
  end

  # DELETE /invites/1
  # DELETE /invites/1.xml
  def destroy
    @invite = Invite.find(params[:id])
    unless @invite.claimed
      @invite.destroy
      flash[:notice] = 'Invitation Removed'
    end
    redirect_to coach_path
  end
end 