module ApplicationCable
  # Visitors connect too, with no user: someone opening a live game's link sees its lobby before joining. Turbo's
  # streams are signed, so only pages the server rendered can listen to one, and channels check who's asking
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = Session.find_by(id: cookies.signed[:session_id])&.user
    end
  end
end
