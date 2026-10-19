# The badges a game earns. Each badge is earned once, by the first game that meets its rule. The rules only
# look at this game and the ones played before it, so working through a player's games in order
# (User#catch_up_badges!) gives the badges they'd have earned at the time
module Attempt::Badgeable
  extend ActiveSupport::Concern

  # Speed badges need a proper game, not three quick answers
  SPEEDY_GAME_ANSWERS = 20
  COMEBACK_AFTER = 7.days

  included do
    has_many :badges, dependent: :nullify
  end

  # Not for a review: ten untimed answers aren't ten in a minute
  def award_badges
    return if review?

    earned = user.badges.pluck(:kind)

    Badge.catalogue.each do |kind|
      user.badges.create!(kind: kind.key, attempt: self, earned_at: played_at) if earned.exclude?(kind.key) && public_send(*kind.check)
    end
  end

  # The rules

  def scored?(topic, target)
    topic_module == topic && score >= target
  end

  # The streak as it stood after this game
  def streak_reached?(days)
    streak >= days
  end

  # Playing a level means it was reached; levelling up reaches the next one
  def reached_level?(topic, number)
    topic_module == topic && (levelled_up ? level + 1 : level) >= number
  end

  def perfect_game?
    perfect? && answered >= Attempt::PERFECT_GAME_ANSWERS
  end

  def speedy?(average_ms)
    answered >= SPEEDY_GAME_ANSWERS && results.sum { |result| result["ms"] } < average_ms * answered
  end

  def played_every_topic?
    counted? && (Topic.keys - earlier_games.counted.distinct.pluck(:topic)).empty?
  end

  # A new best at a topic and level played before, after a week or more without any game
  def comeback?
    return false unless new_high_score && earlier_games.at_level(topic_module, level).where.not(id: id).exists?

    last_played = earlier_games.where.not(id: id).maximum(:played_at)
    last_played.present? && last_played <= played_at - COMEBACK_AFTER
  end

  private
    # This game and the ones played before it
    def earlier_games
      user.attempts.where(played_at: ..played_at)
    end
end
