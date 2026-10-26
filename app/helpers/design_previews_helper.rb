module DesignPreviewsHelper
  def design_preview_path(design)
    query = request.query_parameters.merge("design" => design).to_query
    "#{request.path}?#{query}"
  end

  def design_navigation
    [
      [ "Home", :home, root_path, controller_name == "home" ],
      [ "Practice", :lightning, practice_path, %w[ practice topics lessons ].include?(controller_name) ],
      [ "Compete", :people, groups_path, controller_name.start_with?("group", "head_to_head", "live_game") ],
      [ "Awards", :trophy, awards_path, controller_name == "badges" ],
      [ "Stats", :stats, stats_path, controller_name == "stats" ]
    ]
  end
end
