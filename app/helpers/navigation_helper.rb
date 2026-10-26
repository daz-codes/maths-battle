module NavigationHelper
  def primary_navigation
    page = controller_name
    if page == "attempts" && @attempt
      page = if @attempt.daily_test?
        "daily_challenge"
      elsif @attempt.group? || @attempt.head_to_head? || @attempt.live?
        "groups"
      else
        "practice"
      end
    end
    [
      [ "Home", :home, root_path, %w[ home daily_challenge ].include?(page) ],
      [ "Practice", :lightning, practice_path, %w[ practice topics lessons ].include?(page) ],
      [ "Compete", :people, groups_path, page.start_with?("group", "head_to_head", "live_game") ],
      [ "Awards", :trophy, awards_path, page == "badges" ],
      [ "Stats", :stats, stats_path, page == "stats" ]
    ]
  end
end
