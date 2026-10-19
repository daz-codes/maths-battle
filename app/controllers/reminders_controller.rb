# Daily reminders, from the settings page: turning them on sends this device's push subscription and the
# time picked; turning them off stops them on every device. Like saving settings, turning them on before
# playing makes a guest account
class RemindersController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :update

  def update
    resume_or_start_guest_session.user.turn_on_reminders!(params[:minute], **subscription_params)
    head :no_content
  rescue ActiveRecord::RecordInvalid
    head :unprocessable_entity
  end

  def destroy
    current_player.turn_off_reminders! if current_player.persisted?
    head :no_content
  end

  private
    # As the browser's PushSubscription gives it: { endpoint:, keys: { p256dh:, auth: } }
    def subscription_params
      subscription = params.expect(subscription: [ :endpoint, keys: %i[ p256dh auth ] ])
      { endpoint: subscription[:endpoint].to_s, p256dh: subscription.dig(:keys, :p256dh).to_s, auth: subscription.dig(:keys, :auth).to_s }
    end
end
