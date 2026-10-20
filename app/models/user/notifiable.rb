# Push notifications beyond the daily reminder (User::Remindable): news from a player's groups. They only go to
# devices where reminders are turned on, and never at night in the player's own time zone, when they're skipped
module User::Notifiable
  extend ActiveSupport::Concern

  # Notifications go out from 7am until 8pm
  AWAKE_HOURS = 7...20

  def notify(message)
    return if quiet_hours?

    push_subscriptions.each { |subscription| subscription.deliver(message) }
  end

  # Sent from a job, so a request doesn't wait on the push services
  def notify_later(message)
    NotifyJob.perform_later(self, message) if push_subscriptions.exists?
  end

  def quiet_hours?(now = Time.current)
    AWAKE_HOURS.exclude?(now.in_time_zone(time_zone).hour)
  end
end
