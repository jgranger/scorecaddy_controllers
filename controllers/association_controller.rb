class AssociationController < ApplicationController
  before_filter :authenticate_user!
	
  def index  	
  	@on_team = false # current_user and current_team.id and current_team.id > 0
	if @on_team
  		@team_id = current_team.id
		@team_name = current_team.team_name
	end
  end
end
