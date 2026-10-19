module RemindersHelper
  # 1020 minutes after midnight → "5pm", 1050 → "5:30pm"
  def reminder_time(minute)
    hour, minutes = minute.divmod(60)
    "#{(hour - 1) % 12 + 1}#{":%02d" % minutes if minutes.positive?}#{hour < 12 ? "am" : "pm"}"
  end
end
