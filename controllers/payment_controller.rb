
class PaymentController < ApplicationController
  protect_from_forgery

  @@existing_team_user ||= false

  def index
    @type = set_type
  end

  def submit
    @type = set_type
    @team_name = params[:teamname] || ''
    @card_token = params[:stripetoken] || ''
    @coach_email = params[:email] || ''
    @description = @team_name + ' - ' + @coach_email
    @plan_code = params[:plancode] || ''
    @coupon = params[:coupon] || ''

    if @type == "team"
      if @team_name.length == 0 || @card_token.length == 0 || @coach_email.length == 0 || @plan_code.length == 0
        redirect_to payment_path + "?type=" + @type + "&email=" + @coach_email + "&teamname=" + @team_name, :notice=> 'Please fill in all fields'
        return
      end

      if @team_name.downcase.include? 'scorecaddy'
        redirect_to payment_path + "?type=" + @type + "&email=" + @coach_email + "&teamname=" + @team_name, :notice=> 'Team name cannot include the text Scorecaddy'
        return
      end

      if Rails.env == 'production' && request && request.subdomains.first == "secure" && request.ssl?
        Stripe.api_key = 'sk_live_kSlJgcuydawA90Lx70NotSjC' # prod
      else
        Stripe.api_key = 'sk_test_55Q3Xr4cOnsjDist3oTllKFZ' # test
      end

      customer = Stripe::Customer.create(
          :card=>@card_token,
          :email=>@coach_email,
          :plan=>@plan_code,
          :description=>@description
      )

      @id = customer.id
      @response = customer.to_json.to_s
      @team = Team.new
      @team.team_name = @team_name
      @team.school_name = @team_name
      unless @team.save!
        return redirect_to payment_path, :notice => 'Oops, something went wrong. Please contact us to get this resolved.'
      end

      @payment = Payment.new
      @payment.Team_id = @team.id
      @payment.User_id = 0
      @payment.PaymentDate = Time.now.utc
      @payment.payment_id = customer.id
      @payment.payment_token = @card_token
      @payment.payment_email = @coach_email
      @payment.payment_json = @response
      @payment.refund = false
      @payment.retries = 0

      unless @payment.save!
        return redirect_to payment_path, :notice => 'Oops, something went wrong.  Please contact us to get this resolved.'
      end

    else
      @team = Team.where(:team_name => "Scorecaddy.com").first
    end

  	to_email = @coach_email
    flash[:plan_email] = to_email
    if @plan_code == 'individual-free'
      flash[:plan_name] = 'Free'
      flash[:plan_amount] = '$0'
      flash[:plan_time] = 'month'
    elsif @plan_code == 'team-monthly-9'
      flash[:plan_name] = 'Monthly'
      flash[:plan_amount] = '$9/month'
      flash[:plan_time] = 'month'
    end

    if params[:existing] == 'true'
      @@existing_team_user = true
      @existing = @@existing_team_user
      if params[:on_team] == 'true'
        redirect_to receipt_path(:existing => @existing, :on_team => true), :notice => to_email + ' is already on the Scorecaddy.com team!'
      else
        redirect_to receipt_path(:existing => @existing), :notice => to_email + ' has joined the Scorecaddy.com team!'
      end
    else
      @invite = Invite.new
      #@invite.textcaptcha
      @invite.to = @coach_email
      @invite.team_id = @team.id
      @invite.created_by = 0
      @invite.claimed = false
      @invite.coach = @type == "team" ? true : false
      if @invite.save!
        uri = "#{request.protocol}#{request.host_with_port}"
        TeamMail.invite(to_email ,to_email, @invite.invite, @team_name, @invite.coach, uri).deliver
        #add_signup_team_to_highrise(invite,@team_name,@plan_code) if @type == "team"
        redirect_to receipt_path, :notice => 'Created Invitation for ' + to_email
      else
        redirect_to payment_path, :notice => 'Oops! Somthing went wrong. There was an error emailing your invitation.  Please contact us to get this resolved.'
      end
    end
  end

  def paypal_submit
    @type = params[:type]
    @team_name = params[:teamname] || ''
    @coach_email = params[:email] || ''
    @plan_code = 'team-monthly-9';

    if @team_name.length == 0 || @coach_email.length == 0
      redirect_to payment_path + "?type=" + @type + "&email=" + @coach_email + "&teamname=" + @team_name, :notice=> 'Please fill in all fields'
      return
    end

    if @team_name.downcase.include? 'scorecaddy'
      redirect_to payment_path + "?type=" + @type + "&email=" + @coach_email + "&teamname=" + @team_name, :notice=> 'Team name cannot include the text Scorecaddy'
      return
    end

    @team = Team.new
    @team.team_name = @team_name
    @team.school_name = @team_name
    unless @team.save!
      return redirect_to payment_path, :notice => 'Oops, something went wrong. Please contact us to get this resolved.'
    end

    to_email = @coach_email
    flash[:plan_email] = to_email
    flash[:plan_name] = 'yearly'
    flash[:plan_amount] = '$99'
    flash[:plan_time] = 'year'

    invite = Invite.new
    invite.to = @coach_email
    invite.team_id = @team.id
    invite.created_by = 0
    invite.claimed = false
    invite.coach = @type == "team" ? true : false
    if invite.save!
      uri = "#{request.protocol}#{request.host_with_port}"
      TeamMail.invite(to_email ,to_email, invite.invite, @team_name,invite.coach, uri).deliver
      #add_signup_team_to_highrise(invite,@team_name,@plan_code) if @type == "team"
      redirect_to receipt_path, :notice => 'Created Invitation for ' + to_email
    else
      redirect_to payment_path, :notice => 'Oops! Somthing went wrong. There was an error emailing your invitation.  Please contact us to get this resolved.'
    end
  end

  def paypal_check_email
    email = request.params[:email]
    @team_name = request.params[:teamname]
    user = User.where('lower(email) = ?', email.downcase).first
    @payment_id = params[:paymentId] || ''
    payment = Payment.where(:payment_id => @payment_id).first
    existing_team = false
    on_team = false

    if payment
      redirect_to payment_path + "?type=" + @type + "&email=" + @coach_email + "&teamname" + @team_name, :notice=> 'Sorry, something went wrong with the payment'
      return
    end

    if user
      team = Team.where(:team_name => @team_name).first
      if team
        team_user_exists = TeamUser.where(:team_id => team.id).where(:user_id => user.id).first
      else
        team_user_exists = false
      end
      unless team_user_exists
        team = Team.new
        team.team_name = @team_name
        team.school_name = @team_name

        if team.save
          team_user = TeamUser.new
          team_user.user_id = user.id
          team_user.team_id = team.id
          team_user.active = true
          if user.first_name != nil && user.last_name != nil
            team_user.first_name = user.first_name
            team_user.last_name = user.last_name
          end
          team_user.save
        end
      else
        on_team = true
        existing_team = true
      end
      render :json => {:existing => true, :on_team_paid => on_team, :existing_team => existing_team}
    else
      render :json => {:existing => false, :on_team_paid => on_team, :existing_team => existing_team}
    end
  end

  def upgrade_plan
    @type = set_type
    @team_name = params[:teamname] || ''
    @card_token = params[:stripetoken] || ''
    @coach_email = params[:email] || ''
    @description = @team_name + ' - ' + @coach_email
    @plan_code = params[:plancode] || ''
    @coupon = params[:coupon] || ''

    if @team_name.length == 0 || @card_token.length == 0 || @coach_email.length == 0 || @plan_code.length == 0
      redirect_to payment_path + "?type=" + @type + "&email=" + @coach_email + "&teamname=" + @team_name, :notice=> 'Please fill in all fields'
      return
    end

    if @team_name.downcase.include? 'scorecaddy'
      redirect_to payment_path + "?type=" + @type + "&email=" + @coach_email + "&teamname=" + @team_name, :notice=> 'Team name cannot include the text Scorecaddy'
      return
    end

    if Rails.env == 'production' && request && request.subdomains.first == "secure" && request.ssl?
      Stripe.api_key = 'sk_live_kSlJgcuydawA90Lx70NotSjC' # prod
    else
      Stripe.api_key = 'sk_test_55Q3Xr4cOnsjDist3oTllKFZ' # test
    end

    customer = Stripe::Customer.create(
        :card=>@card_token,
        :email=>@coach_email,
        :plan=>@plan_code,
        :description=>@description
    )

    @id = customer.id
    @response = customer.to_json.to_s
    @team = Team.new
    @team.team_name = @team_name
    @team.school_name = @team_name
    unless @team.save!
      return redirect_to payment_path, :notice => 'Oops, something went wrong. Please contact us to get this resolved.'
    end

    @payment = Payment.new
    @payment.Team_id = @team.id
    @payment.User_id = 0
    @payment.PaymentDate = Time.now.utc
    @payment.payment_id = customer.id
    @payment.payment_token = @card_token
    @payment.payment_email = @coach_email
    @payment.payment_json = @response
    @payment.refund = false
    @payment.retries = 0

    unless @payment.save!
      return redirect_to payment_path, :notice => 'Oops, something went wrong.  Please contact us to get this resolved.'
    end

    to_email = request.params[:email]
    flash[:plan_email] = to_email
    flash[:plan_name] = 'Monthly'
    flash[:plan_amount] = '$9'
    flash[:plan_time] = 'month'
    @@existing_team_user = true
    @existing = @@existing_team_user
    if params[:on_team_paid] == 'true'
      redirect_to receipt_path(:existing => @existing, :on_team_paid => true), :notice => to_email + ' you have signed up for the paid plan!'
    else
      redirect_to receipt_path(:existing => @existing), :notice => to_email + ' you have signed up for the paid plan!'
    end
  end

  def receipt
    @existing = params[:existing]
    @on_team = params[:on_team]
    @on_team_paid = params[:on_team_paid]
    @plan_email = flash[:plan_email]        #|| 'test@processdeveloper.com'
    @plan_name = flash[:plan_name]          #|| 'Monthly'
    @plan_amount = flash[:plan_amount]      #|| '$9'
    @plan_time = flash[:plan_time]          #|| 'month'

    Rails.logger.info "Plan Email: #{@plan_email}, Plan Name: #{@plan_name}, Plan Amount: #{@plan_amount}, Plan Time: #{@plan_time}"

    unless @plan_email && @plan_name && @plan_amount && @plan_time
      redirect_to payment_path
    end
  end

  def check_email
    type = request.params[:type]
    email = request.params[:email]
    @team_name = request.params[:teamname]
    Rails.logger.info "params: ----> #{request.params}"
    user = User.where('lower(email) = ?', email.downcase).first
    team = Team.where(:team_name => "Scorecaddy.com").first

    existing_team = false

    on_team = false

    unless type == "?type=team"
      if user && team
        team_user_exists = TeamUser.where(:team_id => team.id).where(:user_id => user.id).first
        unless team_user_exists
          team_user = TeamUser.new
          team_user.user_id = user.id
          team_user.team_id = 1
          team_user.active = true
          if user.first_name != nil && user.last_name != nil
            team_user.first_name = user.first_name
            team_user.last_name = user.last_name
          end
          team_user.save
        else
          on_team = true
        end
        render :json => {:existing => true, :on_team => on_team}
      else
        render :json => {:existing => false, :on_team => on_team}
      end
    else
      if user
        #TeamUser doesn't have team_name attribute adjust this and feature will be very close
        team = Team.where(:team_name => @team_name).first
        if team
          team_user_exists = TeamUser.where(:team_id => team.id).where(:user_id => user.id).first
        else
          team_user_exists = false
        end
        unless team_user_exists
          team = Team.new
          team.team_name = @team_name
          team.school_name = @team_name

          if team.save
            team_user = TeamUser.new
            team_user.user_id = user.id
            team_user.team_id = team.id
            team_user.active = true
            if user.first_name != nil && user.last_name != nil
              team_user.first_name = user.first_name
              team_user.last_name = user.last_name
            end
            team_user.save
          end
        else
          on_team = true
          existing_team = true
        end
        render :json => {:existing => true, :on_team_paid => on_team, :existing_team => existing_team}
      else
        render :json => {:existing => false, :on_team_paid => on_team, :existing_team => existing_team}
      end
    end
  end

  private

  def set_type
    if params["type"]
      if params["type"] == "individual"
        @type = "individual"
      elsif params["type"] == "team"
        @type = "team"
      end
    end
  end

  def add_signup_team_to_highrise (invite, team_name, plan)

    company = Highrise::Company.create(:name=>team_name,
                            :contact_data => {:email_addresses=>[{:address=>invite.to,:location=>'Work'}]},
                            :background=>'Team created from the admin controller.')

    note = 'Internet signup for the team ' + team_name + ' from the payment page for the plan ' + plan + '. an email was automatically sent to ' + invite.to

    Highrise::Note.create(:body=>note,:subject_id=>company.id,:subject_type=>'Company')

    Highrise::Task.create(:body=>'Follow up with recently invited coach ' + invite.to ,:subject_id=>company.id,:subject_type=>'Company',:due_at=>(DateTime.now + 7.days),:alert_at=>(DateTime.now + 7.days))
  end
end
