module TopicsHelper
  # Under a level's name: its best score and how many right the next star needs, or what earns the first one. Its
  # stars are on its circle already
  def star_progress(user, topic, level)
    stars, needed, best = user.stars(topic, level), topic.star_scores, number_with_delimiter(user.best_score(topic, level))
    return "Best: #{best}" if stars == Attempt::MAX_STARS
    return "Best: #{best} · #{needed[stars + 1]} right for #{pluralize(stars + 1, "star")}" if stars.positive?

    unlocks = topic.level(level + 1) && level == user.unlocked_level(topic)
    safe_join([ "Get #{needed[1]} right for a ", icon(:star), (" and unlock level #{level + 1}" if unlocks) ].compact)
  end

  # Where picking a level in the chooser goes. On the home page it changes what Practise plays (remembered on
  # the device); on the stats page it shows that level's stats
  def level_choice(choosing, topic, number)
    if choosing == :stats
      [ stats_path(topic.slug), { method: :get, params: { level: number } } ]
    else
      [ level_path, { method: :patch, params: { level: number } } ]
    end
  end
end
