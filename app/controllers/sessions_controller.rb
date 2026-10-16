class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }
  rate_limit to: 10, within: 15.minutes, only: :create, name: "account", by: -> { params[:username].to_s.strip.downcase }, with: -> { redirect_to new_session_path, alert: "Try again later." }

  def new
  end

  def create
    if user = User.authenticate_by(username: params[:username].to_s, password: params[:password].to_s)
      destination = after_authentication_url
      switch_session_to user
      redirect_to destination
    else
      redirect_to new_session_path(username: params[:username]), alert: "Try another username or password."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end

  private
    # Signing in on a device where a guest was playing ends the guest's session. Anything the device still
    # keeps for the last player (games not yet uploaded, pages kept for offline) is theirs, so it's forgotten
    def switch_session_to(user)
      terminate_session if authenticated?
      reset_session
      start_new_session_for user
    end
end
