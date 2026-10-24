require "test_helper"

class LiveGamesTest < ActionDispatch::IntegrationTest
  setup do
    @ada, @bob = users(:ada), users(:bob)
    @ada.update!(name: "Ada")
    @bob.update!(name: "Bob")
  end

  def live_set
    JSON.parse(css_select("[data-controller=test]").first["data-test-question-sets-value"]).first
  end

  def play_live(game, right:)
    get play_path("times-tables", live: game.code)
    set = live_set
    results = set["questions"].first(right).map { |question| question.slice("a", "b").merge("given" => question["answer"], "ms" => 1000) }
    post attempts_path, params: { attempt: { topic: "times_tables", level: 1, client_id: set["id"], ticket: set["ticket"], results: results } }, as: :json
    assert_response :created
  end

  test "the host makes a lobby from the Compete page, at their topic and level, with a link to share and a Start button" do
    sign_in_as @ada
    get groups_path
    assert_select "form[action=?] button", live_games_path, text: /Play live/

    post live_games_path
    game = LiveGame.last
    assert_redirected_to live_game_path(game.code)
    follow_redirect!
    assert_select "h1", text: /Live game/
    assert_select "[data-share-text-value*=?]", live_game_url(game.code)
    assert_select "form[action=?] button", live_game_start_path(game.code), text: "Start"
    assert_select "#live-players .rival-row__name", text: "Ada (host)"
    assert_select "turbo-cable-stream-source"

    post live_game_start_path(game.code)
    assert_redirected_to live_game_path(game.code)
    assert_equal "Wait for someone to join first.", flash[:alert]
  end

  test "the host chooses Classic or Power in the lobby, and everyone sees which" do
    game = LiveGame.make(host: @ada, topic: TimesTables, level: 1)
    sign_in_as @ada
    get live_game_path(game.code)
    assert_select "#live-mode", text: /Classic mode: the most right answers wins/
    assert_select "form[action=?] button[aria-current=true]", live_game_path(game.code), text: "Classic"

    patch live_game_path(game.code), params: { mode: "power" }
    assert game.reload.power?
    follow_redirect!
    assert_select "#live-mode", text: /Power mode: the most gems wins/

    sign_in_as @bob
    game.join(@bob)
    get live_game_path(game.code)
    assert_select "#live-mode", text: /Power mode/
    assert_select "form[action=?][method=post] input[name=_method][value=patch]", live_game_path(game.code), count: 0
    patch live_game_path(game.code), params: { mode: "classic" }
    assert_response :not_found
    assert game.reload.power?

    game.start!
    get play_path("times-tables", live: game.code)
    assert JSON.parse(css_select("[data-controller=test]").first["data-test-live-value"])["power"]
    assert_select ".test__rival .icon--gem"
  end

  test "a visitor opens the link, gives a name and joins; the host starts it and everyone plays the same minute" do
    game = LiveGame.make(host: @ada, topic: TimesTables, level: 1)

    get live_game_path(game.code)
    assert_select "input[name=name][required]"
    post live_game_player_path(game.code), params: { name: "Zara" }
    zara = User.find_by(name: "Zara")
    assert game.player?(zara)
    follow_redirect!
    assert_select ".live-status__waiting", text: "Waiting for Ada to start…"
    assert_select "form[action=?]", live_game_start_path(game.code), count: 0

    get play_path("times-tables", live: game.code)
    assert_redirected_to live_game_path(game.code), "not started yet"

    sign_in_as @ada
    post live_game_start_path(game.code)
    assert_redirected_to play_path("times-tables", live: game.code)
    follow_redirect!
    live = JSON.parse(css_select("[data-controller=test]").first["data-test-live-value"])
    assert_equal [ { "id" => zara.id, "name" => "Zara" } ], live["rivals"]
    assert_equal game.player_for(@ada), LiveGame.player_from_pass(live["pass"])
    assert_in_delta 6000, live["startsInMs"], 1500
    assert_select ".test__rival[data-player-id=?]", zara.id.to_s, text: "Zara 0"
    assert_equal game.questions.map { _1["text"] }, live_set["questions"].map { _1["text"] }

    travel 20.seconds do
      play_live(game, right: 7)
      attempt = @ada.attempts.last
      assert_equal "live", attempt.mode
      get attempt_path(attempt)
      assert_select ".banner--group", text: "You came 1st!"
      assert_select "#live-podium .leaderboard__row", count: 2
      assert_select "#live-podium .leaderboard__row", text: /Zara.*playing…/m

      get play_path("times-tables", live: game.code)
      assert_redirected_to live_game_path(game.code), "one go each"
    end
  end

  test "no joining once it's started, and a missing code goes back to Compete" do
    game = LiveGame.make(host: @ada, topic: TimesTables, level: 1)
    game.join(@bob)
    game.start!

    sign_in_as User.create!(username: "carol", password: "a long password 123")
    get live_game_path(game.code)
    assert_select "#live-podium"
    post live_game_player_path(game.code)
    assert_not game.player?(User.find_by(username: "carol"))

    get live_game_path("NOPE22")
    assert_redirected_to groups_path
  end
end
