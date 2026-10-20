# A player's groups, making one, and a group's page: its challenges, and for the owner, how others join
class GroupsController < ApplicationController
  allow_unauthenticated_access only: :index
  rate_limit to: 10, within: 10.minutes, only: :create

  def index
    @user = current_player
    @groups = @user.persisted? ? @user.groups.includes(:owner).order(:name) : []
    @waiting_counts = @user.group_challenges_to_play.group_by(&:group_id).transform_values(&:size)
    @member_counts = Group::Membership.where(group: @groups).group(:group_id).count
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
end
