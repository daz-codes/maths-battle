class ProfilesController < ApplicationController
  allow_unauthenticated_access

  def edit
    @user = current_player
  end

  def update
    @user = resume_or_start_guest_session.user

    if @user.update(params.expect(user: %i[ name theme ]))
      redirect_to root_path, notice: "Saved!"
    else
      render :edit, status: :unprocessable_entity
    end
  end
end
