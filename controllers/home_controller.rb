require "browser"
class HomeController < ApplicationController
  # GET /temps
  # GET /temps.xml

  def index
    if user_signed_in?
      redirect_to :dashboard
    elsif browser.mobile?
      render 'index.mobile'
      elserender "index"
    end
  end
end
