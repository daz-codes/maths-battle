# The gems a player has: what every game they've played earned, less what they've spent (on streak freezes)
module User::Gemmable
  extend ActiveSupport::Concern

  def gems
    gems_earned - gems_spent
  end

  def gems_earned
    @gems_earned ||= attempts.sum(:gems)
  end

  def reload(...)
    @gems_earned = nil
    super
  end
end
