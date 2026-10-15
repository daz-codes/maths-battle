module ApplicationHelper
  # Icons live in public/, so they aren't fingerprinted. Bump this when they change so browsers fetch them again
  ICON_VERSION = 2

  def icon_path(file)
    "/#{file}?v=#{ICON_VERSION}"
  end
end
