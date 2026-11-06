# The Leagues page (today's world league and the player's own leagues), making a league, and a league's page: its
# table today, and for the owner, how others join
class LeaguesController < ApplicationController
  allow_unauthenticated_access only: :index
  rate_limit to: 10, within: 10.minutes, only: :create

  def index
    @user = current_player
    @world = League.world
    @standing = @world.entry_for(@user)
    @yesterday = League.world(League.today - 1).leader
    @leagues = @user.persisted? ? @user.leagues.includes(:owner).order(:name) : []
  end

  def new
    return redirect_to new_registration_path, notice: "Make an account to start a league, so it isn't lost with this device." unless Current.user.can_make_leagues?

    @league = League.new
  end

  def create
    return redirect_to new_registration_path unless Current.user.can_make_leagues?

    @league = Current.user.owned_leagues.new(params.expect(league: [ :name ]))
    if @league.save
      redirect_to @league, notice: "League made! Share its code so others can join."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @league = Current.user.leagues.find(params[:id])
    @standings = @league.standings
    @yesterday = @league.standings(League.today - 1).leader
    @memberships = @league.memberships.includes(:user).sort_by { |membership| membership.user.display_name.to_s.downcase }
  end

  def destroy
    Current.user.owned_leagues.find(params[:id]).destroy
    redirect_to leagues_path, notice: "League deleted."
  end
end
