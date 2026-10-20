# A device that gets its player's daily reminders, as its browser gave it when they were turned on.
# The server sends to the endpoint, so only the browsers' own push services are accepted
class PushSubscription < ApplicationRecord
  PUSH_SERVICES = %r{\Ahttps://([a-z0-9-]+\.)*(fcm\.googleapis\.com|push\.services\.mozilla\.com|push\.apple\.com|notify\.windows\.com)/\S*\z}
  # Whoever reads a reminder hours later doesn't need it
  KEEP_FOR = 6.hours
  NETWORK_ERRORS = [ SocketError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError ]

  belongs_to :user

  validates :endpoint, format: PUSH_SERVICES, length: { maximum: 1_000 }
  validates :p256dh_key, :auth_key, presence: true, length: { maximum: 200 }

  # A device that has unsubscribed, or gone, is forgotten. Any other failure just misses this one
  def deliver(message)
    WebPush.payload_send(message: message.to_json, endpoint: endpoint, p256dh: p256dh_key, auth: auth_key,
      vapid: self.class.vapid, ttl: KEEP_FOR.to_i, urgency: "normal")
    true
  rescue WebPush::ExpiredSubscription, WebPush::InvalidSubscription
    destroy
    false
  rescue WebPush::Error, *NETWORK_ERRORS => error
    Rails.logger.warn("Reminder to push subscription #{id} failed: #{error.class}")
    false
  end

  def self.public_key
    keys[:public_key]
  end

  def self.vapid
    { subject: "https://matheminute.daz.codes", public_key: public_key, private_key: keys[:private_key] }
  end

  # From the credentials, or the test environment's own (config/initializers/web_push.rb)
  def self.keys
    Rails.configuration.x.web_push
  end
end
