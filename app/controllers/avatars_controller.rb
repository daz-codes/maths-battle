class AvatarsController < ApplicationController
  def show
    avatar = Current.user.avatar
    return head :not_found unless avatar.attached?

    response.headers["Cache-Control"] = "private, no-store"
    send_data avatar.download, type: "image/webp", disposition: "inline", filename: "avatar.webp"
  end
end
