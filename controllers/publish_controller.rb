class PublishController < ApplicationController
  include RoundsHelper
  layout false

  def show
    r = Round.where(share_token: params[:share_token]).first
    @current_team = Team.find(r.team_id)
    @round = Round.find(r.id, :include => [:course,:round_holes,{:round_holes=>:round_hole_putts}],:order=>'round_holes.hole ASC, round_hole_putts.putt_number ASC')
    @putting_breakdown = putting_breakdown(@round)
    @chipping_breakdown = chipping_breakdown(@round)
    @leaderboard = leaderboard(@round)
    @missed_putts = missed_putts(@round)
    @made_putts_total_distance = made_putts_total_distance(@round)
    @avg_putt_distance = "%5.1f" % chip_putt_distance(@round)
    if @round.round_holes.length > 0 and !@made_putts_total_distance.nil?
      avg_putt_made_num = Float(@made_putts_total_distance)/Float(@round.round_holes.length)
      @avg_made_putt_length = format("%.1f",avg_putt_made_num)
    else
      @avg_made_putt_length = '-'
    end
    @wedges = wedges(@round)
    @next = Round.next(@round.round_date,@round.team_user_id,@round.id).first
    @previous = Round.previous(@round.round_date,@round.team_user_id,@round.id).first

    if browser.mobile?
      render 'show.mobile'
    end
  end

  def chipping_breakdown(round)
    rv = []
    round.round_holes.each do |hole|
      if hole.is_up_down_attempt?
        first_putt = hole.round_hole_putts.sort_by{|p| p.putt_number }.first
        rv.push({:hole=>hole.hole,:chip_yds=>(hole.chip_yards.nil? ? 0 : hole.chip_yards),:left=>(first_putt != nil ? first_putt.distance_in_ft : 0),:updown=>(hole.up_and_down or (hole.putts == nil or hole.putts == 0))})
      end
    end
    rv
  end

  def putting_breakdown(round)
    lt5_m = 0
    lte8_m = 0
    lte12_m = 0
    lte15_m = 0
    lte20_m = 0
    lte30_m = 0
    gt30_m = 0

    lt5 = 0
    lte8 = 0
    lte12 = 0
    lte15 = 0
    lte20 = 0
    lte30 = 0
    gt30 = 0
    round.round_hole_putts.each do |p|
      if p.distance_in_ft != nil
        if p.distance_in_ft < 5
          lt5 += 1
          if p.holed
            lt5_m +=1
          end
        elsif p.distance_in_ft <=8
          lte8+=1
          if p.holed
            lte8_m +=1
          end
        elsif p.distance_in_ft <=12
          lte12+=1
          if p.holed
            lte12_m +=1
          end
        elsif p.distance_in_ft <=15
          lte15+=1
          if p.holed
            lte15_m +=1
          end
        elsif p.distance_in_ft <=20
          lte20+=1
          if p.holed
            lte20_m +=1
          end
        elsif p.distance_in_ft <=30
          lte30+=1
          if p.holed
            lte30_m +=1
          end
        else
          gt30+=1
          if p.holed
            gt30_m +=1
          end
        end
      end
    end
      # returns  array for each bucket
      # made putts, attempted putts, and missed putts
      {'lt5'=>[lt5_m,lt5,(lt5-lt5_m)],
       'lte8'=>[lte8_m,lte8,(lte8-lte8_m)],
       'lte12'=>[lte12_m,lte12,(lte12-lte12_m)],
       'lte15'=>[lte15_m,lte15,(lte15-lte15_m)],
       'lte20'=>[lte20_m,lte20,(lte20-lte20_m)],
       'lte30'=>[lte30_m,lte30,(lte30-lte30_m)],
       'gt30'=>[gt30_m,gt30,(gt30-gt30_m)]}
  end

  def leaderboard(round)
    rv = []
    to_par = 0
    round.round_holes.each do |hole|
      x = hole.score - hole.par
      to_par += x
      rv.push({:hole=>hole.hole.to_s,:running_total=>format_to_par(to_par),:running_total_number=>to_par,:this_hole=>format_to_par(x), :this_hole_num=>x,:score=>hole.score.to_s,:par=>hole.par.to_s})
    end
    rv
  end

  def made_putts_total_distance(round)
    rv = 0
    round.round_holes.each do |hole|
      hole.round_hole_putts.each do |putt|
        if putt.holed or putt.distance_in_ft.nil?
          rv += putt.distance_in_ft || 0
        end
      end
    end
    rv
  end

  def wedges(round)
    rv = []
    round.round_holes.each do |hole|
      if hole.approach_yards != nil and hole.approach_yards <= 131
        putt = hole.round_hole_putts.sort_by {|a| a.putt_number}.first
        green = hole.approach == 'G'
        distance = (green && putt) ? putt.distance_in_ft : 0
        rv.push({:hole_number=>hole.hole, :approach_distance=>hole.approach_yards, :green=>green, :putt_distance=>distance})
      end
    end
    rv
  end
end
