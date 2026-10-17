# The stars a player has: what every game they've played earned, less what they've spent (on streak freezes)
module User::Starrable
  extend ActiveSupport::Concern

  def stars
    stars_earned - stars_spent
  end

  def stars_earned
    @stars_earned ||= attempts.sum(:stars)
  end

  def reload(...)
    @stars_earned = nil
    super
  end
end
