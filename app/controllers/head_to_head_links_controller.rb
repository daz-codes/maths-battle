# Opening a head to head's link (/c/Xb3…): the challenge, then taking it up and playing. A visitor gets a guest
# account to play with, giving a name if they've none, as their rival sees it
class HeadToHeadLinksController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 60, within: 1.minute, with: -> { redirect_to root_path, alert: "Too many tries. Wait a minute, then try again." }

  before_action :set_head_to_head

  def show
    return redirect_to(@head_to_head) if @head_to_head.player?(Current.user)

    @user = current_player
  end

  def create
    return redirect_to(@head_to_head) if @head_to_head.player?(Current.user)

    player = resume_or_start_guest_session.user
    player.update!(name: params[:name].to_s.strip.first(User::NAME_LENGTH)) if params[:name].present?
    return redirect_to head_to_head_link_path(@head_to_head.share_token), alert: "Tell us your name first: your rival sees it." if player.name.blank? && player.guest?

    if @head_to_head.claim(player)
      redirect_to play_path(@head_to_head.topic_module.slug, head_to_head: @head_to_head.id)
    else
      redirect_to head_to_head_link_path(@head_to_head.share_token)
    end
  end

  private
    def set_head_to_head
      @head_to_head = HeadToHead.sent.includes(:challenger, :challenger_attempt).find_by(share_token: params[:token].to_s)
      redirect_to root_path, alert: "That challenge link doesn't work. Check it and try again." unless @head_to_head
    end
end
