# The Compete page (a player's head to heads and groups), making a group, and a group's page: its challenges, and
# for the owner, how others join
class GroupsController < ApplicationController
  allow_unauthenticated_access only: :index
  rate_limit to: 10, within: 10.minutes, only: :create

  def index
    @user = current_player
    @groups = @user.persisted? ? @user.groups.includes(:owner).order(:name) : []
    @waiting_counts = @user.group_challenges_to_play.group_by(&:group_id).transform_values(&:size)
    @member_counts = Group::Membership.where(group: @groups).group(:group_id).count
    @head_to_heads = recent_head_to_heads
  end

  def new
    return redirect_to new_registration_path, notice: "Make an account to start a group, so it isn't lost with this device." unless Current.user.can_make_groups?

    @group = Group.new
  end

  def create
    return redirect_to new_registration_path unless Current.user.can_make_groups?

    @group = Current.user.owned_groups.new(params.expect(group: [ :name ]))
    if @group.save
      redirect_to @group, notice: "Group made! Share its code so others can join."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @group = Current.user.groups.find(params[:id])
    challenges = @group.challenges.order(created_at: :desc).to_a
    @challenge_cards = Group::Challenge::Listing.new(challenges, user: Current.user).cards
    @memberships = @group.memberships.includes(:user).sort_by { |membership| membership.user.display_name.to_s.downcase }
  end

  def destroy
    Current.user.owned_groups.find(params[:id]).destroy
    redirect_to groups_path, notice: "Group deleted."
  end

  private
    # Sent, or still for the player to play first, latest first
    def recent_head_to_heads
      return [] unless @user.persisted?

      @user.head_to_heads.merge(HeadToHead.sent.or(HeadToHead.where(challenger: @user)))
        .includes(:challenger, :opponent, :challenger_attempt, :opponent_attempt).order(updated_at: :desc).limit(10)
    end
end
