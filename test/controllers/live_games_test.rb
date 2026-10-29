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
    assert_select "form[action=?] button", live_games_path, text: /Play Live/
    assert_select "form[action=?] button svg", live_games_path, 1, "with the lightning bolt"

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

  test "the host picks the topic and level in the lobby, a new set of questions, before it starts" do
    game = LiveGame.make(host: @ada, topic: TimesTables, level: 1)
    sign_in_as @ada
    get live_game_path(game.code)
    assert_select "#live-mode", text: /Times tables · Level 1/
    assert_select "form[action=?] select[name=topic] option[selected][value=times_tables]", live_game_path(game.code)
    assert_select "select[name=level] option[value=mixed]", count: 0, message: "a live game is at one level"

    patch live_game_path(game.code), params: { topic: "percentages", level: 3 }
    game.reload
    assert_equal [ "percentages", 3 ], [ game.topic, game.level ]
    assert_match "%", game.questions.first["text"]
    follow_redirect!
    assert_select "#live-mode", text: /Percentages · Level 3/

    patch live_game_path(game.code), params: { topic: "percentages", level: 9 }
    assert_equal 3, game.reload.level, "no such level"
    game.join(@bob)
    game.start!
    patch live_game_path(game.code), params: { topic: "addition", level: 1 }
    assert_equal "percentages", game.reload.topic, "not once it's started"
  end

  test "the host chooses Classic or Power in the lobby, and everyone sees which" do
    game = LiveGame.make(host: @ada, topic: TimesTables, level: 1)
    sign_in_as @ada
    get live_game_path(game.code)
    assert_select "#live-mode", text: /Classic mode: the highest score wins/
    assert_select "form[action=?] button[aria-current=true]", live_game_path(game.code), text: "Classic"

    patch live_game_path(game.code), params: { mode: "power" }
    assert game.reload.power?
    follow_redirect!
    assert_select "#live-mode", text: /Power mode: the highest score wins, with power-ups/

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
    live = JSON.parse(css_select("[data-controller=test]").first["data-test-live-value"])
    assert live["power"]
    assert_equal [ LiveGame::BOX_EVERY.in_milliseconds, LiveGame::BOXES ], live.values_at("boxEveryMs", "boxes")
    assert_equal LiveGame::POWER_UPS.keys, live["powerUps"].keys
    assert_select ".icon--gem", count: 0
    assert_select "button.test__power[hidden]"
    assert_select "template[data-power-up=freeze]"
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

  test "a code typed on the Compete page, any case and spacing, goes to its lobby" do
    game = LiveGame.make(host: @ada, topic: TimesTables, level: 1)
    sign_in_as @bob
    get groups_path
    assert_select "form[action=?][method=get] input[name=code]", live_games_path

    get live_games_path, params: { code: " #{game.code.downcase.chars.join(" ")} " }
    assert_redirected_to live_game_path(game.code)
    follow_redirect!
    assert_select "input[type=submit][value=?]", "Join the game"

    get live_games_path, params: { code: "" }
    follow_redirect!
    assert_redirected_to groups_path
  end

  test "the lobby shows its code big, to read out" do
    game = LiveGame.make(host: @ada, topic: TimesTables, level: 1)
    sign_in_as @ada
    get live_game_path(game.code)
    assert_select ".live-code", text: game.code
    assert_select "[data-share-text-value*=?]", "code #{game.code}"
  end

  test "after the game the host plays again, and the others find the next lobby from their result" do
    game = LiveGame.make(host: @ada, topic: TimesTables, level: 1)
    game.join(@bob)
    game.start!

    travel 20.seconds do
      sign_in_as @bob
      play_live(game, right: 3)
      get attempt_path(@bob.attempts.last)
      assert_select "#live-again", text: /If Ada plays again/
      post live_game_rematch_path(game.code)
      assert_response :not_found, "only the host"

      sign_in_as @ada
      play_live(game, right: 5)
      get attempt_path(@ada.attempts.last)
      assert_select "#live-again form[action=?] button", live_game_rematch_path(game.code), text: /Play again/
      post live_game_rematch_path(game.code)
      rematch = game.reload.rematch
      assert_redirected_to live_game_path(rematch.code)

      sign_in_as @bob
      get attempt_path(@bob.attempts.last)
      assert_select "#live-again form[action=?] button", live_game_player_path(rematch.code), text: /Play again/
      post live_game_player_path(rematch.code)
      assert_equal [ @ada, @bob ], rematch.users.to_a
    end
  end
end
