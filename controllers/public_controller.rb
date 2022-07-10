class PublicController < ApplicationController
  def benefits
    @title = 'Scorecaddy.com - Benefits'
  end

  def screenshots
    @title = 'Scorecaddy.com - Screenshots'
  end

  def features
    @title = 'Scorecaddy.com - Features'
  end

  def pricing
    @title = 'Scorecaddy.com - Pricing'
  end

  def data
    @title = 'Scorecaddy.com - Analytics Video'
  end

  def input
    @title = 'Scorecaddy.com - Input a Round Video'
  end
end
