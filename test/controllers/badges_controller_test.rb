require "test_helper"

class BadgesControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:ada) }

  test "shows every badge, with the earned ones picked out" do
    Attempt.record!(user: @user, results: answers(*right_answers(10)))
    sign_in_as @user

    get awards_path
    assert_response :success
    assert_select "h1", text: "Awards"
    assert_select ".aside", text: "5 of #{Badge.catalogue.size} unlocked", message: "first game, 5 and 10 in a minute, a perfect game, and level 2 for a bronze"
    assert_select ".badge:not(.badge--locked) .badge__name", text: "First minute"
    assert_select ".badge--locked .badge__name", text: "1 week streak"
    assert_select ".badge--locked .badge__how", text: /Play 7 days in a row/
    assert_select ".badge:not(.badge--locked) .badge__how", text: /#{Time.current.strftime("%-d %b %Y")}/
    assert_select ".badge", Badge.catalogue.size
  end

  test "the old badges and achievements addresses go to awards" do
    get "/badges"
    assert_redirected_to "/awards"
    get "/achievements"
    assert_redirected_to "/awards"
  end

  test "visitors see them all still to earn" do
    get awards_path
    assert_response :success
    assert_select ".badge--locked", Badge.catalogue.size
  end

  test "the results page celebrates new badges" do
    sign_in_as @user
    Attempt.record!(user: @user, results: answers(*right_answers(5)))
    attempt = Attempt.record!(user: @user, results: answers(*right_answers(5)))
    @user.badges.where.not(kind: "first_game").update_all(attempt_id: attempt.id)

    get attempt_path(attempt)
    assert_select ".badges--new[data-controller~=confetti][data-controller~=award-reveal] .badge__name", text: "5 times tables in a minute"
    assert_select ".badges--new .label", text: "New awards!", message: "5 times tables, and level 2"
    assert_select "a[href=?]", awards_path, text: "See your awards"
  end

  test "one lot of confetti: a level up already has it" do
    sign_in_as @user
    attempt = Attempt.record!(user: @user, results: answers(*right_answers(5)))

    get attempt_path(attempt)
    assert_select ".banner[data-controller~=confetti]", text: /Level up/
    assert_select ".badges--new .badge__name", text: "First minute"
    assert_select ".badges--new[data-controller~=confetti]", count: 0
    assert_select ".badges--new[data-controller=award-reveal]", message: "it still spins in"
  end

  test "a shared result shows its badges, still without the player's name" do
    player = User.create!(username: "secret_squirrel", name: "Sammy", password: "a long enough password")
    attempt = Attempt.record!(user: player, results: answers(*right_answers(5)))

    get share_path(attempt.share_token)
    assert_select ".badges--new .badge__name", text: "First minute"
    assert_select ".badges--new[data-controller]", count: 0
    assert_no_match(/squirrel|Sammy/, response.body)
  end

  test "the stats page shows how many have been unlocked" do
    Attempt.record!(user: @user, results: answers(*right_answers(5)))
    sign_in_as @user

    get stats_path
    assert_select "a.badge-summary[href=?]", awards_path, text: /3 of #{Badge.catalogue.size} unlocked/
    assert_equal %w[ icon--party icon--star icon--target ], css_select(".badge-summary__icons .icon").map { _1["class"][/icon--\w+/] }.sort, "first game, 5 right and level 2"
  end
end
