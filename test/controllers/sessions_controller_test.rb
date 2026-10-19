require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:ada) }

  test "new" do
    get new_session_path
    assert_response :success
  end

  test "signs in by username" do
    post session_path, params: { username: "Ada", password: "password" }

    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "the session cookie lasts, so children stay signed in" do
    post session_path, params: { username: "ada", password: "password" }
    assert_match(/expires=/i, response.headers["Set-Cookie"].to_s)
  end

  test "create with invalid credentials" do
    post session_path, params: { username: "ada", password: "wrong" }

    assert_redirected_to new_session_path(username: "ada")
    assert_nil cookies[:session_id]
  end

  test "a sign in with a field missing just asks again" do
    post session_path, params: { username: "ada" }
    assert_redirected_to new_session_path(username: "ada")

    post session_path
    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
  end

  test "signing in replaces the player's identity" do
    choose_topic
    get root_path
    previous = response.headers.fetch("X-Player-Key")
    post session_path, params: { username: "ada", password: "password" }
    assert_not_equal previous, response.headers.fetch("X-Player-Key")
    follow_redirect!
    assert_select "meta[name=player-key][content=?]", response.headers.fetch("X-Player-Key")
  end

  test "expired sessions cannot read private results" do
    attempt = Attempt.record!(user: @user, results: answers([ 2, 3, 6 ]))
    sign_in_as @user
    Current.session.update!(created_at: (Session::LIFETIME + 1.day).ago)
    get attempt_path(attempt)
    assert_redirected_to new_session_path
  end

  test "destroy" do
    sign_in_as(@user)

    delete session_path

    assert_redirected_to new_session_path
    assert_empty cookies[:session_id]
  end

  test "player versions increase even when sign in and sign out share the same timestamp" do
    travel_to Time.current do
      get root_path
      previous = response.headers.fetch("X-Player-Version").to_i
      post session_path, params: { username: "ada", password: "password" }
      signed_in = response.headers.fetch("X-Player-Version").to_i
      assert_operator signed_in, :>, previous
      delete session_path
      assert_operator response.headers.fetch("X-Player-Version").to_i, :>, signed_in
    end
  end
end
