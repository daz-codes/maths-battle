# Reminders go out with WebPush. Tests catch what would have been sent instead, or make sending fail
module PushTestHelper
  PUSH_ENDPOINT = "https://fcm.googleapis.com/fcm/send/device-1"

  def push_keys(endpoint: PUSH_ENDPOINT)
    { endpoint: endpoint, p256dh: "BPublicKeyOfTheBrowser", auth: "AuthSecret" }
  end

  # The pushes sent while the block runs, each with its message parsed
  def pushes_sent(failing_with: nil)
    sent = []
    original = WebPush.method(:payload_send)
    WebPush.define_singleton_method(:payload_send) do |**push|
      raise failing_with if failing_with

      sent << push.merge(message: JSON.parse(push[:message], symbolize_names: true))
    end
    yield
    sent
  ensure
    WebPush.define_singleton_method(:payload_send, original)
  end

  def push_response_error(error_class)
    error_class.new(Struct.new(:body).new(""), "fcm.googleapis.com")
  end
end
