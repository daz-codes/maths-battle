class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }

  def new
  end

  def create
    if user = User.authenticate_by(params.permit(:username, :password))
      switch_session_to user
      redirect_to after_authentication_url
    else
      redirect_to new_session_path(username: params[:username]), alert: "Try another username or password."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end

  private
    # Signing in on a device where a guest was playing ends the guest's session
    def switch_session_to(user)
      terminate_session if authenticated?
      start_new_session_for user
    end
end
