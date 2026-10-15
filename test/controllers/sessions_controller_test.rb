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

  test "destroy" do
    sign_in_as(@user)

    delete session_path

    assert_redirected_to new_session_path
    assert_empty cookies[:session_id]
  end
end
