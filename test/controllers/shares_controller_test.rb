require "test_helper"

class SharesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "secret_squirrel", password: "a long secret phrase")
    play_daily_challenge(@user)
    @attempt = Attempt.record!(user: @user, results: answers(*right_answers(6)))
  end

  test "works signed out and shows the result without the username" do
    get share_path(@attempt.share_token)

    assert_response :success
    assert_select ".card__number", text: "6"
    assert_select "body", text: /A MatheMinute player/
    assert_no_match(/squirrel/i, response.body)
    assert_select "main .avatar", count: 0, message: "the sharer's picture is never shown"
    assert_select "a[href=?]", root_path, text: "Try MatheMinute!"
  end

  test "is hidden from search engines and previews nicely" do
    get share_path(@attempt.share_token)

    assert_select "meta[name=robots][content=noindex]"
    assert_select "meta[property='og:title'][content=?]", "6 in a minute! 🔥 1 day streak"
    assert_select "meta[property='og:description']"
  end

  test "the preview names the topic played" do
    get share_path(@attempt.share_token)
    assert_select "meta[property='og:description'][content=?]", "A MatheMinute player got 6 times tables right in 60 seconds. Can you beat it?"

    equations = Attempt.record!(user: @user, topic: "equations", results: [ { type: "x+a=b", a: 2, b: 5, v: "x", flip: false, given: "3", ms: 1000 } ])
    get share_path(equations.share_token)
    assert_select "meta[property='og:description'][content=?]", "A MatheMinute player got 1 equations right in 60 seconds. Can you beat it?"
  end

  test "unknown tokens are not found" do
    get share_path("nope")
    assert_response :not_found
  end
end
