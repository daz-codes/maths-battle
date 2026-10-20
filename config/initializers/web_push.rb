# The keys that sign daily reminders (PushSubscription), from the credentials. The test environment sets its
# own pair first, as CI has no master key to read the credentials with
Rails.application.config.x.web_push = Rails.application.config.x.web_push.presence || Rails.application.credentials.web_push || {}
