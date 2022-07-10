class PasswordsController < Devise::PasswordsController
  skip_before_filter :authenticate_user!
  def new
    super
  end

  def edit
    redirect_to "http://scorecaddy.com"
  end
end