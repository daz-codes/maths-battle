# One player's push notification (User::Notifiable), checked for quiet hours when it's sent
class NotifyJob < ApplicationJob
  queue_as :default
  discard_on ActiveJob::DeserializationError

  def perform(user, message)
    user.notify(message.symbolize_keys)
  end
end
