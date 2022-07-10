class MessageController < ApplicationController
  before_filter :authenticate_user!
  before_filter :coaches_only

  def add
    userid = params[:user_id]
    msg = params[:message]
    if userid.to_i != nil and !msg.nil? and !msg.blank?
      message = Message.new
      message.user_id = userid.to_i
      message.message_text = msg
      message.sender_id = current_user.id
      message.team_id = current_team.id
      message.viewed = false
      if message.save
        return render :json => {:success=>true, :message=>msg}
      end

      render :json => {:success=>false}
    end
  end

  def delete
    @message = Message.find(params[:id])
    if current_team_user.is_coach or current_user.id == @message.user_id
      @message.viewed=true
      @message.viewed_on=DateTime.now
      @message.save
      render :json => {:success=>true,:id=>params[:id]}
    else
      render :json => {:success=>false,:id=>params[:id]}
    end
  end
end
