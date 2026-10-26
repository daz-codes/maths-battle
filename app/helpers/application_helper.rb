module ApplicationHelper
  THEME_COLOURS = { "light" => "#f3f6fb", "dark" => "#10121b" }.freeze

  def colour_preference
    current_player.theme.presence_in(User::THEMES) || "system"
  end

  def theme_colour(scheme)
    THEME_COLOURS.fetch(colour_preference == "system" ? scheme : colour_preference)
  end

  # Icons live in public/, so they aren't fingerprinted. Bump this when they change so browsers fetch them again
  ICON_VERSION = 3

  def icon_path(file)
    "/#{file}?v=#{ICON_VERSION}"
  end
end
