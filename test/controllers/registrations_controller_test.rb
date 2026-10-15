require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "new" do
    get new_registration_path
    assert_response :success
  end

  test "signs up with a username and signs in" do
    assert_difference -> { User.count } do
      post registration_path, params: { user: { username: "Zara", password: "1234" } }
    end

    assert_redirected_to root_path
    assert cookies[:session_id]
    follow_redirect!
    assert_select ".streak__number", text: /0/
  end

  test "shows errors for a taken username" do
    assert_no_difference -> { User.count } do
      post registration_path, params: { user: { username: "ada", password: "1234" } }
    end

    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /Username has already been taken/
  end
end
