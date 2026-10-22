# Sending a head to head as a link, like matheminute.daz.codes/c/Xb3…, for a friend who isn't in a group with the
# challenger. Whoever opens it first and plays becomes the opponent, and from then on they're rivals who can rematch.
# A link only shows the challenger's name and score
module HeadToHead::Linkable
  extend ActiveSupport::Concern

  included do
    has_secure_token :share_token
  end

  def link?
    opponent_id.nil?
  end

  # Taking up the challenge from its link, while it's open and no one else has
  def claim(user)
    with_lock do
      return false unless link? && open? && user.id != challenger_id

      update!(opponent: user)
    end
  end

  def share_text(url)
    "#{challenger.display_name} scored #{challenger_attempt.score} in a minute at #{title}. Can you beat it? #{url}"
  end
end
