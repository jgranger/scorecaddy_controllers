require 'json'
class ApiPlayerController < ApplicationController
  include ApplicationHelper
  include RoundsHelper
  include PlayerHelper
  before_filter :require_ssl
  before_filter :authenticate_user!

  respond_to :json

  def last
    round = Round.where(:team_id => current_team.id).order('updated_at DESC').first
    render :json=> {:last_updated=>round.updated_at.to_f}
  end

  def list
    team_users = TeamUser.that_are_on_team(current_team.id)
    @players = User.joins(:team_users).where('team_users.id IN (?)',team_users).where('exclude_rounds = ? and active = ?',false,true).map{|player|
          {:player_id=>player.id, :name=>player.short_name}
        }
    render :json=>@players.as_json
  end

  def rounds
    if ensure_player_data_secure(params)
      player_id = Integer(params[:id])
      raw_rounds = nil
      if player_id > 0
        raw_rounds = Round.includes(:round_holes).includes(:round_holes => :round_hole_putts).where('rounds.user_id = ?', player_id).all
      end
      query = PlayerQuery.new(params)
      rounds = get_rounds(query)

      render :json => rounds.as_json
    else
      raise 'Unauthorized Access Exception'
      #render :json => {:error => 'unauthorized'}
    end
  end
end