require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "new" do
    get new_registration_path
    assert_response :success
  end

  test "signs up with a username and signs in" do
    assert_difference -> { User.count } do
      post registration_path, params: { user: { name: "Zara", username: "zara_b", password: "1234" } }
    end

    assert_redirected_to root_path
    assert cookies[:session_id]
    follow_redirect!
    assert_select ".greeting", text: "Hi Zara!"
  end

  test "a name, username and password are all needed" do
    assert_no_difference -> { User.count } do
      post registration_path, params: { user: { name: "", username: "", password: "" } }
    end

    assert_response :unprocessable_entity
    assert_select "[role=alert] li", 3
  end

  test "a guest who signs up keeps their streak and history" do
    post attempts_path, params: { attempt: { results: answers(*right_answers(5)) } }, as: :json
    guest = User.last
    assert guest.guest?

    assert_no_difference -> { User.count } do
      post registration_path, params: { user: { name: "Zara", username: "zara_b", password: "1234" } }
    end

    guest.reload
    assert_equal "zara_b", guest.username
    assert_equal 1, guest.current_streak
    assert_equal 1, guest.attempts.count
    assert_equal guest, User.authenticate_by(username: "zara_b", password: "1234")
  end

  test "shows errors for a taken username" do
    assert_no_difference -> { User.count } do
      post registration_path, params: { user: { name: "Ada", username: "ada", password: "1234" } }
    end

    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /Username has already been taken/
  end
end
