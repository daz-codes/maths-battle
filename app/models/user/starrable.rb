# The stars a player has collected, from every game they've played
module User::Starrable
  extend ActiveSupport::Concern

  def stars
    @stars ||= attempts.sum(:stars)
  end
end
