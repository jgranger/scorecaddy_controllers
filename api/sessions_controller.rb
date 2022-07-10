class SessionsController < ApplicationController
  before_filter :ensure_params_exist
  before_filter :require_ssl
  respond_to :json
  
  def create
    resource = User.find_for_database_authentication(:email=>params[:login])
    return invalid_login_attempt unless resource

    if resource.valid_password?(params[:password])
      sign_in("user", resource)
      resource.save
      render :json=> {:success=>true, :auth_token=>resource.authentication_token, :login=>resource.email, :email=>resource.email}
      return
    end
    invalid_login_attempt
  end
  
  def destroy
    sign_out(resource_name)
  end

  protected
    
  def ensure_params_exist
    return unless params[:login].blank?
    return unless params[:password].blank?
    render :json=>{:success=>false, :message=>"missing login"}, :status=>422
  end

  def invalid_login_attempt
    warden.custom_failure!
    render :json=> {:success=>false, :message=>"Error with your login or password"}, :status=>401
  end  
end

