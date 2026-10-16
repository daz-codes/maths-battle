Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.base_uri :self
    policy.object_src :none
    policy.frame_ancestors :none
    policy.form_action :self
    policy.script_src :self
    policy.style_src :self, "https://fonts.googleapis.com"
    # Stats bars and small client-side previews set individual style attributes.
    policy.style_src_attr :unsafe_inline
    policy.font_src :self, "https://fonts.gstatic.com"
    policy.img_src :self, :data, :blob
    policy.connect_src :self
    policy.worker_src :self

    if (cdn = ENV["CDN_HOST"].presence)
      policy.script_src :self, cdn
      policy.style_src :self, "https://fonts.googleapis.com", cdn
      policy.img_src :self, :data, :blob, cdn
      policy.connect_src :self, cdn
    end
  end

  config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]
end
