require "test_helper"

class GuestPlayTest < ActionDispatch::IntegrationTest
  test "a visitor can take the test" do
    get play_path("times-tables")
    assert_response :success
  end

  test "the first saved test makes a guest account with a session on this device" do
    assert_difference -> { User.count } => 1, -> { Session.count } => 1 do
      post attempts_path, params: { attempt: { results: answers(*right_answers(5)) } }, as: :json
    end

    assert_response :created
    assert cookies[:session_id]
    guest = User.last
    assert guest.guest?

    follow_redirect = response.parsed_body["url"]
    get follow_redirect
    assert_response :success
    assert_select ".save-nudge a[href=?]", new_registration_path
  end

  test "later tests go to the same guest" do
    post attempts_path, params: { attempt: { results: answers(*right_answers(5)) } }, as: :json

    assert_no_difference -> { User.count } do
      post attempts_path, params: { attempt: { results: answers(*right_answers(6)) } }, as: :json
    end
    assert_equal 2, User.last.attempts.count
    assert_equal 6, User.last.best_score(TimesTables, 1)
  end

  test "visiting pages doesn't create guests" do
    assert_no_difference -> { User.count } do
      get root_path
      get play_path("times-tables")
      get edit_profile_path
    end
  end

  test "signing in as a real user ends the guest session" do
    post attempts_path, params: { attempt: { results: answers(*right_answers(5)) } }, as: :json
    guest_session = Session.last

    post session_path, params: { username: "ada", password: "password" }
    assert_not Session.exists?(guest_session.id)
    assert_equal users(:ada), Session.last.user
  end
end
