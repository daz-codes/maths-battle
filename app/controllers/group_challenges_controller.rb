# A group's challenges: the owner sets one (a topic, level and how long it runs), and everyone sees its
# leaderboard. Its round's questions are made once, when it's set, so everyone plays the same ones
class GroupChallengesController < ApplicationController
  def new
    @group = Current.user.owned_groups.find(params[:group_id])
    @challenge = @group.challenges.new(topic: current_topic.key, level: 1)
  end

  def create
    @group = Current.user.owned_groups.find(params[:group_id])
    @challenge = @group.challenges.new(challenge_params)
    if @challenge.save
      redirect_to group_challenge_path(@group, @challenge), notice: "Challenge set!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  # An every day challenge has today's leaderboard, and the week's by total or best day (?board=total, best)
  def show
    @group = Current.user.groups.find(params[:group_id])
    @challenge = @group.challenges.find(params[:id])
    @round = @challenge.round
    @leaderboard = @challenge.leaderboard(@round)
    @board = @challenge.daily? && %w[ total best ].include?(params[:board]) ? params[:board] : "today"
    @week_leaderboard = @challenge.week_leaderboard(by: @board.to_sym) unless @board == "today"
  end

  private
    # The topic and level come as one choice, like "times_tables:2"
    def challenge_params
      details = params.expect(group_challenge: %i[ topic_level daily duration owner_plays ])
      topic, level = details[:topic_level].to_s.split(":")
      duration = Group::Challenge::DURATIONS.fetch(details[:duration], nil)
      { topic: topic, level: level.to_i, daily: details[:daily] == "1", owner_plays: details[:owner_plays] == "1", ends_at: (duration.from_now if duration) }
    end
end
