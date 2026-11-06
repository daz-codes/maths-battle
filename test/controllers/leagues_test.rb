require "test_helper"

class LeaguesTest < ActionDispatch::IntegrationTest
  test "the world league shows today's best scores" do
    play(users(:ada), rights: [ true ] * 3)
    play(users(:bob), rights: [ true ] * 2)
    get leagues_path
    assert_select ".leaderboard__row", 2
    assert_select ".leaderboard__row:first-child .leaderboard__name", text: "Ada"
  end

  test "making a league, joining it with its code and seeing its table" do
    sign_in_as users(:ada)
    post leagues_path, params: { league: { name: "Class 4B" } }
    league = League.last
    assert_redirected_to league
    sign_out

    sign_in_as users(:bob)
    get join_league_path(league.join_code)
    assert_response :success
    post league_joins_path, params: { code: league.join_code }
    assert_redirected_to league
    play(users(:bob), rights: [ true ] * 2)
    get league_path(league)
    assert_select ".leaderboard__name", text: /Bob/
  end

  test "a visitor joining gives a name" do
    league = League.create!(owner: users(:ada), name: "Smiths")
    post league_joins_path, params: { code: league.join_code }
    assert_redirected_to join_league_path(league.join_code)
    post league_joins_path, params: { code: league.join_code, name: "Dot" }
    assert_redirected_to league
    assert league.member?(User.find_by(name: "Dot"))
  end

  test "a guest can't make a league" do
    post attempts_path, params: game_upload, as: :json
    get new_league_path
    assert_redirected_to new_registration_path
  end

  test "only members see a league" do
    league = League.create!(owner: users(:ada), name: "Smiths")
    sign_in_as users(:bob)
    get league_path(league)
    assert_response :not_found
  end
end
