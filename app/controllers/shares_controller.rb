# The public page a shared result links to. Shows nothing that identifies the player
class SharesController < ApplicationController
  allow_unauthenticated_access

  def show
    @attempt = Attempt.find_by!(share_token: params[:share_token])
  end
end
