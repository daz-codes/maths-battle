# Daily reminders: a push notification at a time the player picks, if they haven't done a daily challenge by
# then, like "Your 12 day streak is waiting", or a group challenge is waiting for them. The time is the player's,
# in their own time zone; each device that should get it has a push subscription. Checked every 15 minutes
# (config/recurring.yml)
module User::Remindable
  extend ActiveSupport::Concern

  # Every half hour from 7am to 9pm, as minutes after midnight
  REMINDER_MINUTES = (7 * 60..21 * 60).step(30).to_a
  DEFAULT_REMINDER_MINUTE = 17 * 60
  # A reminder that couldn't go at its time (the server was down, say) isn't sent hours late
  LATE_BY = 2.hours

  included do
    has_many :push_subscriptions, dependent: :destroy
    validates :reminder_minute, inclusion: { in: REMINDER_MINUTES }, allow_nil: true
  end

  class_methods do
    def send_due_reminders(now = Time.current)
      where.not(reminder_minute: nil).where.associated(:push_subscriptions).distinct.find_each do |user|
        user.remind if user.reminder_due?(now)
      end
    end
  end

  def reminders_on?
    reminder_minute.present?
  end

  # This device gets the reminders, at that time. A device moves to whoever turned reminders on there last
  def turn_on_reminders!(minute, endpoint:, p256dh:, auth:)
    transaction do
      PushSubscription.find_or_initialize_by(endpoint: endpoint).update!(user: self, p256dh_key: p256dh, auth_key: auth)
      update!(reminder_minute: minute)
    end
  end

  # Off everywhere
  def turn_off_reminders!
    transaction do
      push_subscriptions.destroy_all
      update!(reminder_minute: nil)
    end
  end

  def reminder_due?(now = Time.current)
    local = now.in_time_zone(time_zone)
    late = local.seconds_since_midnight.to_i / 60 - reminder_minute
    reminders_on? && reminded_on != local.to_date && late.between?(0, LATE_BY.in_minutes) && (!practised_today? || group_challenges_to_play.any?)
  end

  def remind
    update!(reminded_on: today)
    push_subscriptions.each { |subscription| subscription.deliver(reminder_message) }
  end

  # The daily challenge if it's still to do, saying if a group challenge is waiting too; or just the group's
  def reminder_message
    waiting = group_challenges_to_play.first
    group_line = "#{waiting.group.name}'s challenge is waiting" if waiting

    if practised_today?
      { title: "🏆 #{group_line}", body: "#{waiting.title}. Everyone plays the same questions!", url: Rails.application.routes.url_helpers.group_challenge_path(waiting.group_id, waiting) }
    elsif streak.positive?
      { title: "🔥 Your #{streak} day streak is waiting", body: [ "Play today's daily challenge to keep it going.", ("#{group_line} too." if group_line) ].compact.join(" "), url: "/" }
    else
      { title: "⭐ Your daily challenge is ready", body: [ "One minute of maths. Play it to start a streak!", ("#{group_line} too." if group_line) ].compact.join(" "), url: "/" }
    end
  end
end
