module NavigationHelper
  def primary_navigation
    page = controller_name
    page = @attempt.battle? ? "multiplayer" : "home" if page == "attempts" && @attempt
    [
      [ "Home", :home, root_path, page == "home" ],
      [ "Multiplayer", :versus, multiplayer_path, %w[ multiplayer matches live_games ].include?(page) ],
      [ "Leagues", :people, leagues_path, page.start_with?("league") ],
      [ "Awards", :trophy, awards_path, page == "awards" ]
    ]
  end
end
