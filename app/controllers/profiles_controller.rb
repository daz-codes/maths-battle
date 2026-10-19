class ProfilesController < ApplicationController
  allow_unauthenticated_access
  # Saving settings before playing makes a guest account, so this stops anyone making them by the thousand
  rate_limit to: 10, within: 3.minutes, only: :update, with: -> { redirect_to edit_profile_path, alert: "Try again later." }

  def edit
    @user = current_player
  end

  def update
    @user = resume_or_start_guest_session.user

    if @user.update(profile_params)
      redirect_to root_path, notice: "Saved!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def profile_params
      params.expect(user: %i[ name theme sounds avatar_upload remove_avatar ])
    end
end
