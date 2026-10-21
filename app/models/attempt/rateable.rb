# Stars: a level's practice game earns 1, 2 or 3 stars for its score (each topic sets the scores), the level keeps
# the most stars its games have earned, and the first star unlocks the next level. Only practice earns stars:
# mixed practice, reviews and group games aren't a level's own. (Gems are what games earn to spend: Gemmable)
module Attempt::Rateable
  extend ActiveSupport::Concern

  MAX_STARS = 3

  class_methods do
    # The stars a score earns in a topic, 0 to 3
    def stars_for(score, topic)
      topic.star_scores.find { |_, needed| score >= needed }&.first || 0
    end
  end

  def stars
    practice? ? self.class.stars_for(score, topic_module) : 0
  end

  # This game's stars, if they're more than the level had before
  def new_stars
    stars if stars > self.class.stars_for(previous_best, topic_module)
  end

  # The level's best practice score before this game, 0 if it's the first
  def previous_best
    user.attempts.at_level(topic_module, level).where(id: ...id).maximum(:score).to_i
  end

  private
    # The first star at a level unlocks the next one
    def first_star?
      practice? && score >= topic_module.star_scores[1] && previous_best < topic_module.star_scores[1]
    end
end
