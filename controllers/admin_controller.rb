class AdminController < ApplicationController
  before_filter :is_admin

  def test
  end

  def users
    @users = User.order('created_at DESC')
  end

  def invites
    @invites = Invite.where("claimed = ?",false).order('created_at DESC')
  end

  def invite_coach
    @teams = Team.all.map{|t| [t.team_name,t.id]}
    @teams.insert(0,["New Team...",0])
  end

  def add_coach
    if params[:team_id].nil?
      render :action => "invite_coach"
    end

    team_id = Integer(params[:team_id])
    is_new = false

    if team_id == 0
      is_new = true
      @team = Team.new
      @team.team_name = params[:team_name]
      @team.school_name = params[:school_name] or ''
      unless @team.save
        flash[:alert] = 'Error Creating Team for Invitation'
        return redirect_to admin_invite_coach_path
      end
      team_id = @team.id
      team_name = @team.team_name
    else
      @team = Team.find(team_id)
      team_name = @team.team_name
    end

  	to_email = request.params[:email]
    user = User.where('lower(email) = ?',to_email.downcase).first
    unless user
      # if email is valid
      invite = Invite.new
      invite.to = to_email
      invite.team_id = team_id
      invite.created_by = current_user.id
      invite.claimed = false
      invite.coach = true
      if invite.save
        data = 'Coach Invite Created for: ' + to_email + ' Invite Code: ' + invite.invite + ' Invitation URL: https://secure.scorecaddy.com/users/sign_up?invite_code=' +  URI.escape(invite.invite) + '&email=' + URI.escape(to_email)
        flash[:notice] = data

        if is_new
          add_invite_team_to_highrise(invite,team_name,params[:send_mail],data)
        end

        if params[:send_mail]
          uri = "#{request.protocol}#{request.host_with_port}"

          TeamMail.invite(current_user.full_name + ' ' + current_user.email ,to_email, invite.invite, team_name, true, uri).deliver
        end
        redirect_to admin_invites_path
      else
        flash[:alert] = 'Error Creating Invitation.'
        redirect_to admin_invite_coach_path
      end
    else
      begin
        existing_team_user = TeamUser.where(:team_id => team_id).where(:user_id => user.id).first
        unless existing_team_user
          team_user = TeamUser.new
          team_user.user_id = user.id
          team_user.team_id = team_id
          team_user.save

          flash[:notice] = 'User added to ' + team_name

          if params[:send_mail]
            uri = "#{request.protocol}#{request.host_with_port}"
            AddCurrentUserToTeamMail.invite('golf@scorecaddy.com', to_email,team_name,true, uri).deliver
          end
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


  def add_invite_team_to_highrise (invite, team_name, mail_sent, data)
    company = Highrise::Company.create(:name=>team_name,
                            :contact_data => {:email_addresses=>[{:address=>invite.to,:location=>'Work'}]},
                            :background=>'Team created from the admin controller.')

    note = current_user.full_name + ' created invitation for the team ' + team_name + ' from the admin panel.'
    if mail_sent
      note = note + ' an email was automatically sent to ' + invite.to
    else
      note = note + ' an email was NOT automatically sent. There should be manual follow up to occur.'
    end
    note = note + ' Invitation Data: ' + data
    Highrise::Note.create(:body=>note,:subject_id=>company.id,:subject_type=>'Company')

    unless mail_sent
      Highrise::Task.create(:body=>'Send Manual email to coach at ' + invite.to ,:subject_id=>company.id,:subject_type=>'Company',:due_at=>DateTime.now,:alert_at=>DateTime.now)
    end

    Highrise::Task.create(:body=>'Follow up with recently invited coach ' + invite.to ,:subject_id=>company.id,:subject_type=>'Company',:due_at=>(DateTime.now + 7.days),:alert_at=>(DateTime.now + 7.days))
  end

  def rounds
    @rounds = Round.where('team_id != 8 AND team_id != 1').order('updated_at DESC').limit(100)

  end

  def demo_data
    re_create_demo_data
  end

  def re_create_demo_data
    day_offset = [38,32,28,24,17,16,9,7,6,2,1]

    team_id = Team.where(:team_name => "Scorecaddy.com").first.id
    courses = Course.all
    player_list = TeamUser.where('is_coach = ?', false).where('team_id = ?', team_id)

    player_list.each do |p|
        day_offset.each do |offset|

        round_date = offset.days.ago
        round_course_id = (offset % courses.length)
        holes_randomized = (1..18).sort_by {rand}
        holes_to_alter = Set.new(holes_randomized[0..rand(16)])
        course = courses[round_course_id]
        round = Round.new
        round.team_user_id = p.id        
        round.course_id = course.id
        round.team_id = current_team.id
        round.active=true
        round.round_date = round_date.to_date
        round.season = current_team.season

        unless course.nil?
          course.holes.each do |hole|

            if holes_to_alter.include?(hole.hole_number)
              alter_type = rand(18)
              case alter_type
                when 1,2,3,4,16 then add_birdie_hole(round,hole)
                when 5 then add_birdie_hole_eagle_if_par_5(round,hole)
                when 6,7,8,9,10,15,17 then add_par_up_down_hole(round,hole)
                when 11,12 then add_bogey_missed_up_down_hole(round,hole)
                when 13 then add_bogey_three_putt_hole(round,hole)
                when 14 then add_double_penalty_hole(round,hole)
                else add_birdie_hole_chip_in(round,hole)
              end
              logger.info 'altering hole ' + hole.to_s
            else
              @hole = add_par_hole(round,hole)
              logger.info 'easy par on hole ' + hole.to_s
            end
          end
          round.save
        end

      end
    end

    redirect_to admin_demo_data_path
  end

  private
  def get_approach_yards(hole)
    case hole.par
      when 3
        hole.yards
      when 4
        (hole.yards - (rand(50)+245))
      when 5
        (rand(80) + 60)
    end
  end
  def add_par_hole(round, chole)
    @hole = round.round_holes.build
    @hole.active = true
    @hole.team_user_id = round.team_user_id
    @hole.team_id = round.team_id
    @hole.hole = chole.hole_number
    @hole.course_id = chole.course_id
    @hole.par = chole.par
    @hole.yards = chole.yards
    @hole.score = chole.par
    @hole.putts = 2
    @hole.drive = get_fairway if chole.par > 3
    @hole.approach = 'G'
    @hole.modified_by = current_user.id
    @hole.created_by = current_user.id
    @hole.approach_yards = get_approach_yards(chole)
    @hole.chip_yards = 0

    @putt1 = @hole.round_hole_putts.build
    @putt1.putt_number = 1
    @putt1.distance_in_ft = (rand(20) + 8)
    @putt1.holed = false

    @putt2 = @hole.round_hole_putts.build
    @putt2.putt_number = 2
    @putt2.distance_in_ft = (rand(5) + 1)
    @putt2.holed = true

    @hole
  end

  def add_double_penalty_hole(round, chole)
    @hole = round.round_holes.build
    @hole.active = true
    @hole.team_user_id = round.team_user_id
    @hole.team_id = round.team_id
    @hole.hole = chole.hole_number
    @hole.course_id = chole.course_id
    @hole.par = chole.par
    @hole.yards = chole.yards
    @hole.score = chole.par+2
    @hole.putts = 2
    @hole.drive = get_fairway if chole.par > 3
    @hole.approach = 'G'
    @hole.modified_by = current_user.id
    @hole.created_by = current_user.id
    @hole.approach_yards = get_approach_yards(chole)
    @hole.chip_yards = 0
    @hole.extra_shot = true

    @putt1 = @hole.round_hole_putts.build
    @putt1.putt_number = 1
    @putt1.distance_in_ft = (rand(20) + 5)
    @putt1.holed = false

    @putt2 = @hole.round_hole_putts.build
    @putt2.putt_number = 2
    @putt2.distance_in_ft = (rand(5) + 1)
    @putt2.holed = true

    @hole

  end

  def add_bogey_three_putt_hole(round, chole)
    @hole = round.round_holes.build
    @hole.active = true
    @hole.team_user_id = round.team_user_id
    @hole.team_id = round.team_id
    @hole.hole = chole.hole_number
    @hole.course_id = chole.course_id
    @hole.par = chole.par
    @hole.yards = chole.yards
    @hole.score = chole.par+1
    @hole.putts = 3
    @hole.drive = get_fairway if chole.par > 3
    @hole.approach = 'G'
    @hole.modified_by = current_user.id
    @hole.created_by = current_user.id
    @hole.approach_yards = get_approach_yards(chole)
    @hole.chip_yards = 0

    @putt1 = @hole.round_hole_putts.build
    @putt1.putt_number = 1
    @putt1.distance_in_ft = (rand(30) + 10)
    @putt1.holed = false

    @putt2 = @hole.round_hole_putts.build
    @putt2.putt_number = 2
    @putt2.distance_in_ft = (rand(6) + 1)
    @putt2.holed = false

    @putt3 = @hole.round_hole_putts.build
    @putt3.putt_number = 2
    @putt3.distance_in_ft = (rand(3) + 1)
    @putt3.holed = true

    @hole

  end

  def add_bogey_missed_up_down_hole(round, chole)
    @hole = round.round_holes.build
    @hole.active = true
    @hole.team_user_id = round.team_user_id
    @hole.team_id = round.team_id
    @hole.hole = chole.hole_number
    @hole.course_id = chole.course_id
    @hole.par = chole.par
    @hole.yards = chole.yards
    @hole.score = chole.par+1
    @hole.putts = 2
    @hole.drive = get_fairway if chole.par > 3
    @hole.approach = get_missed_green
    @hole.modified_by = current_user.id
    @hole.created_by = current_user.id
    @hole.approach_yards = get_approach_yards(chole)
    @hole.chip_yards = rand(30) + 5
    @hole.up_and_down = false

    @putt1 = @hole.round_hole_putts.build
    @putt1.putt_number = 1
    @putt1.distance_in_ft = (rand(15) + 5)
    @putt1.holed = false

    @putt2 = @hole.round_hole_putts.build
    @putt2.putt_number = 2
    @putt2.distance_in_ft = (rand(3) + 1)
    @putt2.holed = true

    @hole

  end

  def get_fairway
    frandom = rand(10)
    fairway = 'F'
    case frandom
      when 1,2
        fairway = 'L'
      when 3,4
        fairway = 'R'
    end
    fairway
  end

  def get_missed_green
    randomizer = rand(3)
    green = 'S'
    case randomizer
      when 1
        green = 'L'
      when 2
        green = 'R'
      when 3
        green = 'O'
    end
    green
  end

  def add_par_up_down_hole(round, chole)
    @hole = round.round_holes.build
    @hole.active = true
    @hole.team_user_id = round.team_user_id
    @hole.team_id = round.team_id
    @hole.hole = chole.hole_number
    @hole.course_id = chole.course_id
    @hole.par = chole.par
    @hole.yards = chole.yards
    @hole.score = (chole.par)
    @hole.putts = 1
    @hole.drive = get_fairway if chole.par > 3
    @hole.approach = get_missed_green
    @hole.modified_by = current_user.id
    @hole.created_by = current_user.id
    @hole.approach_yards = get_approach_yards(chole)
    @hole.chip_yards = (rand(34) + 1)
    @hole.up_and_down = true

    @putt1 = @hole.round_hole_putts.build
    @putt1.putt_number = 1
    @putt1.distance_in_ft = (rand(7) + 1)
    @putt1.holed = true

    @hole
  end

  def add_birdie_hole(round, chole)
    @hole = round.round_holes.build
    @hole.active = true
    @hole.team_user_id = round.team_user_id
    @hole.team_id = round.team_id
    @hole.hole = chole.hole_number
    @hole.course_id = chole.course_id
    @hole.par = chole.par
    @hole.yards = chole.yards
    @hole.score = (chole.par-1)
    @hole.putts = 1
    @hole.drive = 'F' if chole.par > 3
    @hole.approach = 'G'
    @hole.modified_by = current_user.id
    @hole.created_by = current_user.id
    @hole.approach_yards = get_approach_yards(chole)
    @hole.chip_yards = 0

    @putt1 = @hole.round_hole_putts.build
    @putt1.putt_number = 1
    @putt1.distance_in_ft = (rand(17) + 1)
    @putt1.holed = true

    @hole
  end

  def add_birdie_hole_chip_in(round, chole)
    @hole = round.round_holes.build
    @hole.active = true
    @hole.team_user_id = round.team_user_id
    @hole.team_id = round.team_id
    @hole.hole = chole.hole_number
    @hole.course_id = chole.course_id
    @hole.par = chole.par
    @hole.yards = chole.yards
    @hole.score = (chole.par-1)
    @hole.putts = 0
    @hole.drive = get_fairway if chole.par > 3
    @hole.approach = get_missed_green
    @hole.modified_by = current_user.id
    @hole.created_by = current_user.id
    @hole.approach_yards = get_approach_yards(chole)
    @hole.chip_yards = rand(25) + 5
    @hole.up_and_down = true

    @hole
  end

  def add_birdie_hole_eagle_if_par_5(round, chole)
    p5 = false
    p5 = true if chole.par == 5
    @hole = round.round_holes.build
    @hole.active = true
    @hole.team_user_id = round.team_user_id
    @hole.team_id = round.team_id
    @hole.hole = chole.hole_number
    @hole.course_id = chole.course_id
    @hole.par = chole.par
    @hole.yards = chole.yards
    @hole.score = (chole.par-1)
    @hole.score = (chole.par-2) if chole.par == 5
    @hole.putts = 1
    @hole.drive = 'F' if chole.par > 3
    @hole.approach = 'G'
    @hole.modified_by = current_user.id
    @hole.created_by = current_user.id
    if chole.par == 5
      @hole.approach_yards = (rand(80) + 180)
    else
      @hole.approach_yards = get_approach_yards(chole)
    end
    @hole.chip_yards = 0
    @putt1 = @hole.round_hole_putts.build
    @putt1.putt_number = 1
    @putt1.distance_in_ft = (rand(16) + 1)
    @putt1.holed = true

    @hole
  end
end
