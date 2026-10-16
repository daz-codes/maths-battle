module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?, :current_player, :player_key, :player_identity_version
    after_action :identify_player
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private
    def authenticated?
      resume_session
    end

    def require_authentication
      resume_session || request_authentication
    end

    def resume_session
      Current.session ||= find_session_by_cookie
    end

    def find_session_by_cookie
      Session.active.find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
    end

    # Whoever is playing: a signed in user, a guest, or a visitor who hasn't played yet (unsaved)
    def current_player
      @current_player ||= (Current.user if authenticated?) || User.new
    end

    # Guests don't sign up: their first save quietly gives them an account and a session on this device
    def resume_or_start_guest_session
      resume_session || start_new_session_for(User.create_guest!, identity: player_identity)
    end

    def request_authentication
      session[:return_to_after_authenticating] = request.url
      redirect_to new_session_path
    end

    def after_authentication_url
      session.delete(:return_to_after_authenticating) || root_url
    end

    def start_new_session_for(user, identity: nil)
      user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
        Current.session = session
        cookies.signed[:session_id] = { value: session.id, expires: session.expires_at, httponly: true, same_site: :lax }
        write_player_identity(user.id, identity)
      end
    end

    def terminate_session
      Current.session.destroy
      Current.session = nil
      @current_player = nil
      cookies.delete(:session_id)
      write_player_identity(nil)
    end

    # This identifies a browser's player, never authenticates them. Keeping it in a signed, HTTP-only
    # cookie lets an unsaved visitor keep their identity when their first game creates a guest.
    def player_key
      player_identity.fetch("key")
    end

    def player_identity_version
      player_identity.fetch("version")
    end

    def player_identity
      @player_identity ||= begin
        identity = cookies.signed[:player_identity]
        user_id = resume_session&.user_id
        if identity.is_a?(Hash) && identity["user_id"] == user_id
          identity
        else
          write_player_identity(user_id)
        end
      end
    end

    def write_player_identity(user_id, previous = nil)
      last = @player_identity || cookies.signed[:player_identity]
      last_version = last.is_a?(Hash) ? last.fetch("version", 0).to_i : 0
      @player_identity = {
        "key" => previous&.fetch("key") || SecureRandom.hex(16),
        "version" => previous&.fetch("version") || [ (Time.current.to_f * 1_000_000).to_i, last_version + 1 ].max,
        "user_id" => user_id
      }
      cookies.signed.permanent[:player_identity] = { value: @player_identity, httponly: true, same_site: :lax }
      @player_identity
    end

    def identify_player
      response.set_header("X-Player-Key", player_key)
      response.set_header("X-Player-Version", player_identity.fetch("version").to_s)
      response.set_header("X-Player-Expires", (resume_session&.expires_at || Session::LIFETIME.from_now).iso8601)
    end
end
