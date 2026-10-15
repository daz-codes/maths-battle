require "test_helper"

class SharesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "secret_squirrel", password: "1234")
    @attempt = Attempt.record!(user: @user, results: answers(*right_answers(6)))
  end

  test "works signed out and shows the result without the username" do
    get share_path(@attempt.share_token)

    assert_response :success
    assert_select ".card__number", text: "6"
    assert_select "body", text: /A MatheMinute player/
    assert_no_match(/squirrel/i, response.body)
    assert_select "a[href=?]", root_path, text: "Try MatheMinute!"
  end

  test "is hidden from search engines and previews nicely" do
    get share_path(@attempt.share_token)

    assert_select "meta[name=robots][content=noindex]"
    assert_select "meta[property='og:title'][content=?]", "6 in a minute! 🔥 1 day streak"
    assert_select "meta[property='og:description']"
  end

  test "unknown tokens are not found" do
    get share_path("nope")
    assert_response :not_found
  end
end
