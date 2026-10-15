module StatsHelper
  def seconds(ms)
    ms ? "#{(ms / 1000.0).round(1)}s" : "—"
  end

  def percent(value)
    value ? "#{value}%" : "—"
  end
end
