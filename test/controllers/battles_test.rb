require "test_helper"

class BattlesTest < ActionDispatch::IntegrationTest
  test "hosting, joining and starting a battle, then playing it" do
    sign_in_as users(:ada)
    post live_games_path
    game = LiveGame.last
    assert_redirected_to live_game_path(game)
    get live_game_path(game)
    assert_select ".live-code", text: game.code
    sign_out

    sign_in_as users(:bob)
    post live_game_player_path(game)
    assert game.player?(users(:bob))
    sign_out

    sign_in_as users(:ada)
    post live_game_start_path(game)
    assert_redirected_to play_path(live: game.code)
    travel LiveGame::START_LEAD + 1.second
    get play_path(live: game.code)
    assert_response :success
    live = JSON.parse(css_select("main.test").first["data-test-live-value"])
    assert_equal [ "Bob" ], live["rivals"].map { |rival| rival["name"] }

    owner = response.headers.fetch("X-Player-Key")
    post attempts_path, params: game_upload(live_game: game, powers: [], owner: owner), as: :json
    assert_response :created
    assert_equal "battle", Attempt.last.mode
    get JSON.parse(response.body)["url"]
    assert_select ".live-podium"
  end

  test "a battle not started yet, or not theirs, sends them to its page" do
    game = LiveGame.host!(users(:ada))
    sign_in_as users(:bob)
    get play_path(live: game.code)
    assert_redirected_to live_game_path(game.code)
  end

  test "a code that's no battle goes back to multiplayer" do
    get live_games_path(code: "zzzzz")
    follow_redirect!
    assert_redirected_to multiplayer_path
  end

  test "finding a match asks a visitor's name, then looks" do
    post match_path
    assert_redirected_to match_path
    post match_path, params: { name: "Dot" }
    assert_redirected_to match_path(looking: 1)
    follow_redirect!
    assert_select "[data-controller=matchmaking]"
  end
end
