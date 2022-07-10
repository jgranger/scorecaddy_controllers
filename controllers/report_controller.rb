class ReportController < ApplicationController
  def index
    output = HelloReport.new.to_pdf
    send_data output, :filename => "hello.pdf", :type => "application/pdf"
  end

  def round    
    @user = current_user
    @round = Round.find(params[:id], :include => [:course,:round_holes,{:round_holes=>:round_hole_putts}],:order=>'round_holes.hole ASC, round_hole_putts.putt_number ASC')
    report = RoundReport.new
    report.user = current_user
    report.round = @round
    report.team  = current_team
    output = report.to_pdf
    send_data output, :filename => "round.pdf", :type => "application/pdf"
  end
end