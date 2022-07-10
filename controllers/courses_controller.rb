class CoursesController < ApplicationController
  before_filter :authenticate_user!
  before_filter :redirect_if_not_on_team

  # GET /courses
  def index
        state_abbr = {
      'AL' => 'Alabama',
      'AK' => 'Alaska',
      'AS' => 'America Samoa',
      'AZ' => 'Arizona',
      'AR' => 'Arkansas',
      'CA' => 'California',
      'CO' => 'Colorado',
      'CT' => 'Connecticut',
      'DE' => 'Delaware',
      'DC' => 'District of Columbia',
      'FM' => 'Micronesia1',
      'FL' => 'Florida',
      'GA' => 'Georgia',
      'GU' => 'Guam',
      'HI' => 'Hawaii',
      'ID' => 'Idaho',
      'IL' => 'Illinois',
      'IN' => 'Indiana',
      'IA' => 'Iowa',
      'KS' => 'Kansas',
      'KY' => 'Kentucky',
      'LA' => 'Louisiana',
      'ME' => 'Maine',
      'MH' => 'Islands1',
      'MD' => 'Maryland',
      'MA' => 'Massachusetts',
      'MI' => 'Michigan',
      'MN' => 'Minnesota',
      'MS' => 'Mississippi',
      'MO' => 'Missouri',
      'MT' => 'Montana',
      'NE' => 'Nebraska',
      'NV' => 'Nevada',
      'NH' => 'New Hampshire',
      'NJ' => 'New Jersey',
      'NM' => 'New Mexico',
      'NY' => 'New York',
      'NC' => 'North Carolina',
      'ND' => 'North Dakota',
      'OH' => 'Ohio',
      'OK' => 'Oklahoma',
      'OR' => 'Oregon',
      'PW' => 'Palau',
      'PA' => 'Pennsylvania',
      'PR' => 'Puerto Rico',
      'RI' => 'Rhode Island',
      'SC' => 'South Carolina',
      'SD' => 'South Dakota',
      'TN' => 'Tennessee',
      'TX' => 'Texas',
      'UT' => 'Utah',
      'VT' => 'Vermont',
      'VI' => 'Virgin Island',
      'VA' => 'Virginia',
      'WA' => 'Washington',
      'WV' => 'West Virginia',
      'WI' => 'Wisconsin',
      'WY' => 'Wyoming',
      'NONUS' => 'Non US'
    }

    @courses = []
    @team_courses = []
    @team_user_courses = []
    @team_courses_list = current_team.team_courses.all
    @team_user_courses_list = current_team_user.team_user_courses.all

    @team_courses_list.each do |tc|
      @team_courses << Course.find(tc.course_id)
    end

    @team_user_courses_list.each do |tuc|
      @team_user_courses << Course.find(tuc.course_id)
    end

    if params[:state] and state_abbr[params[:state].upcase]
      @state_name = state_abbr[params[:state].upcase]
      if params[:state].upcase == 'NONUS'
        @courses = Course.where("country != 'USA'").order(:name).all
      else
        @courses = Course.where(:state => params[:state]).order(:name).all
      end
    elsif params[:filter] == 'TEAM'
      @courses = @team_courses
    elsif params[:filter] == 'MY_COURSES'
      @courses = @team_user_courses
    else
  	  @courses = Course.order(:name).all
      @team_courses = Course.order(:name).all
      @team_user_courses = Course.order(:name).all
    end

    if browser.mobile?
      render 'index.mobile'
    end

    @team = current_team
  end

  # GET /courses/1
  def show
    @course = Course.where(id: params[:id]).includes(:holes).first
    @readonly = true
  end

  # GET /courses/new
  def new
  	@course = Course.new
    @course.country="USA"
  	18.times do |i|
  		h = @course.holes.build
  		h.hole_number = i+1
  	end
  end

  # GET /courses/1/edit
  def edit
  	@course = Course.where(id: params[:id]).includes(:holes).first
  	@readonly = false
  end

  # POST /courses
  def create
  	@course = Course.new(params[:course])
  	@course.created_by = current_user.id
  	@course.modified_by = current_user.id

  	if @course.save
  		redirect_to(courses_url, :notice => 'Course was successfully created.')
  	else
  		render :action => "new"
  	end
  end

  # PUT /courses/1
  def update
    @course = Course.find(params[:id])
    @course.modified_by = current_user.id
    if @course.update_attributes(params[:course])
      redirect_to(courses_url, :notice => 'Course was successfully updated.')
    else
      render :action => "edit"
    end
  end

  def associate_team_course
    course = Course.find(params[:id])
    existing = TeamCourse.where(:team_id => current_team.id).where(:course_id => course.id).first
    unless existing
      team_course = TeamCourse.new(:team_id => current_team.id, :course_id => course.id)
      if team_course.save
        flash[:notice] = "Course added to team"
      else
        flash[:notice] = "Course could not be added to team"
      end
    end
    redirect_to(courses_url)
  end

  def disassociate_team_course
    course = Course.find(params[:id])
    existing = TeamCourse.where(:team_id => current_team.id).where(:course_id => course.id).first

    if existing
      if TeamCourse.delete(existing.id)
        flash[:notice] = "Course removed from Team"
      else
        flash[:notice] = "Course could not be removed from team"
      end
    end
    redirect_to(courses_url)
  end

  def associate_team_user_course
    course = Course.find(params[:id])
    existing = TeamUserCourse.where(:team_user_id => current_team_user.id).where(:course_id => course.id).first
    unless existing
      team_user_course = TeamUserCourse.new(:team_user_id => current_team_user.id, :course_id => course.id)
      if team_user_course.save
        flash[:notice] = "Course added to your courses"
      else
        flash[:notice] = "Course could not be added to your courses"
      end
    end
    redirect_to(courses_url)
  end

  def disassociate_team_user_course
    course = Course.find(params[:id])
    existing = TeamUserCourse.where(:team_user_id => current_team_user.id).where(:course_id => course.id).first

    if existing
      if TeamUserCourse.delete(existing.id)
        flash[:notice] = "Course removed from your courses"
      else
        flash[:notice] = "Course could not be removed from your courses"
      end
    end
    redirect_to(courses_url)
  end

  private

  def redirect_if_not_on_team
    if current_user != nil and (current_team.id == nil or current_team.id < 1)
      redirect_to '/'
    end
  end
end
