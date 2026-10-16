module TopicsHelper
  # Where picking a topic or level in the chooser goes. On the home page it changes what Play plays
  # (remembered on the device); on the stats page it shows that topic's or level's stats
  def topic_choice(choosing)
    choosing == :stats ? [ stats_path, :get ] : [ topic_path, :patch ]
  end

  def level_choice(choosing, topic, number)
    if choosing == :stats
      [ stats_path(topic.slug), { method: :get, params: { level: number } } ]
    else
      [ level_path, { method: :patch, params: { level: number } } ]
    end
  end
end
