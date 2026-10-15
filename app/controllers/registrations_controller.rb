# Signing up. A guest who has already played keeps their account, so their streak carries over
class RegistrationsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_registration_path, alert: "Try again later." }
  before_action :redirect_registered_users

  def new
    @user = current_player
  end

  def create
    @user = current_player

    if @user.register(registration_params)
      start_new_session_for @user unless authenticated?
      redirect_to root_path, notice: "You're signed up, #{@user.display_name}!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def registration_params
      params.expect(user: %i[ name username password ])
    end

    def redirect_registered_users
      redirect_to root_path if authenticated? && !Current.user.guest?
    end
end
