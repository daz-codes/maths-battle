# Stars: a level's practice game earns 1, 2 or 3 stars for how many it got right (each topic sets how many), the level
# keeps the most stars its games have earned, and the first star unlocks the next level. Only practice earns stars:
# mixed practice, reviews and group games aren't a level's own. Stars go by right answers, a plain measure of fluency;
# the score, with speed and runs of right answers, is the best to beat (Scorable)
module Attempt::Rateable
  extend ActiveSupport::Concern

  MAX_STARS = 3

  class_methods do
    # The stars so many right earns in a topic, 0 to 3
    def stars_for(correct, topic)
      topic.star_scores.find { |_, needed| correct >= needed }&.first || 0
    end
  end

  def stars
    practice? ? self.class.stars_for(correct, topic_module) : 0
  end

  # This game's stars, if they're more than the level had before
  def new_stars
    stars if stars > self.class.stars_for(previous_best_correct, topic_module)
  end

  # The level's best practice score before this game, 0 if it's the first
  def previous_best
    earlier_at_level.maximum(:score).to_i
  end

  # The most it had got right before this game
  def previous_best_correct
    earlier_at_level.maximum(:correct).to_i
  end

  private
    # The first star at a level unlocks the next one
    def first_star?
      practice? && correct >= topic_module.star_scores[1] && previous_best_correct < topic_module.star_scores[1]
    end

    def earlier_at_level
      user.attempts.at_level(topic_module, level).where(id: ...id)
    end
end
