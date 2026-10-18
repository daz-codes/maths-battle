module TopicsHelper
  # Where picking a topic or level in the chooser goes. On the home page it changes what Play plays
  # (remembered on the device); on the stats page it shows that topic's or level's stats
  def topic_choice(choosing)
    choosing == :stats ? [ stats_path, :get ] : [ topic_path, :patch ]
  end

  # Under a medal level's name: its best medal and the next to aim for, or what earns the first one
  # (which unlocks the next level). "🥈 Silver · best 24 · 30 for gold"
  def medal_progress(user, topic, level)
    medal, needed = user.medal(topic, level), topic.medals
    best = user.best_score(topic, level)

    case medal
    when :gold then "#{Attempt::MEDAL_EMOJI[:gold]} Gold · best #{best}"
    when :silver then "#{Attempt::MEDAL_EMOJI[:silver]} Silver · best #{best} · #{needed[:gold]} for gold"
    when :bronze then "#{Attempt::MEDAL_EMOJI[:bronze]} Bronze · best #{best} · #{needed[:silver]} for silver"
    else
      unlocks = topic.level(level + 1) && level == user.unlocked_level(topic)
      "Score #{needed[:bronze]} for #{Attempt::MEDAL_EMOJI[:bronze]} bronze#{" and unlock level #{level + 1}" if unlocks}"
    end
  end

  def level_choice(choosing, topic, number)
    if choosing == :stats
      [ stats_path(topic.slug), { method: :get, params: { level: number } } ]
    else
      [ level_path, { method: :patch, params: { level: number } } ]
    end
  end
end
