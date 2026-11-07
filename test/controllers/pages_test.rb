require "test_helper"

class PagesTest < ActionDispatch::IntegrationTest
  test "the home page offers single player and multiplayer" do
    get root_path
    assert_response :success
    assert_select "a[href=?]", play_path, text: /Single player/
    assert_select "a[href=?]", multiplayer_path, text: /Multiplayer/
  end

  test "the home page shows where they are in the world league, their records, and a link to how it works" do
    play(users(:ada), rights: [ true ] * 3)
    sign_in_as users(:ada)
    get root_path
    assert_select ".stats--home .stats__tile", 4
    assert_select ".stats__tile--league dd", text: /1st/
    assert_select ".stats--home dd", text: "60"
    assert_select ".how-link a[href=?]", how_it_works_path
    assert_select ".how-to", count: 0
  end

  test "the awards page shows them all, with the ones earned picked out" do
    play(users(:ada), rights: [ true ] * 3)
    sign_in_as users(:ada)
    get awards_path
    assert_select ".badge", Badge.catalogue.size
    assert_select ".badge:not(.badge--locked) .badge__name", text: "First minute"
  end

  test "a game's results lead with Play again, and show the awards it earned" do
    sign_in_as users(:ada)
    get attempt_path(play(users(:ada), rights: [ true ] * 3))
    assert_select ".button--again[href=?]", play_path
    assert_select ".badges--new .badge__name", text: "First minute"
  end

  test "a solo game's page carries its ladder and the power-ups dealt" do
    get play_path
    assert_response :success
    game = JSON.parse(css_select("main.test").first["data-test-game-value"])
    assert_equal Ladder::TIERS.size, game["pools"].size
    assert_equal Ladder::DEGREES, game.dig("ladder", "degrees")
    assert_equal PowerUp::MOST, game["powers"].size
    assert game["pools"].first.first.key?("answer")
  end

  test "multiplayer, find a match, and the leagues show to anyone" do
    [ multiplayer_path, match_path, leagues_path, awards_path, how_it_works_path, new_session_path, new_registration_path, edit_profile_path ].each do |path|
      get path
      assert_response :success, path
    end
  end

  test "a signed in player's pages" do
    sign_in_as users(:ada)
    play(users(:ada))
    [ root_path, multiplayer_path, leagues_path, new_league_path, edit_profile_path, attempt_path(users(:ada).attempts.last) ].each do |path|
      get path
      assert_response :success, path
    end
  end
end
