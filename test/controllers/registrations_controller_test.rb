require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "new" do
    get new_registration_path
    assert_response :success
  end

  test "signs up with a username and signs in" do
    assert_difference -> { User.count } do
      post registration_path, params: { user: { name: "Zara", username: "zara_b", password: "a long secret phrase" } }
    end

    assert_redirected_to root_path
    assert cookies[:session_id]
    follow_redirect!
    assert_redirected_to topics_path, "a new player picks a topic first"
    patch topic_path, params: { topic: "functions" }
    follow_redirect!
    assert_select ".greeting", text: /Hi Zara!/
  end

  test "a name, username and password are all needed" do
    assert_no_difference -> { User.count } do
      post registration_path, params: { user: { name: "", username: "", password: "" } }
    end

    assert_response :unprocessable_entity
    assert_select "[role=alert] li", 3
  end

  test "a guest who signs up keeps their streak and history" do
    post attempts_path, params: game_upload(results: answers(*right_answers(5))), as: :json
    guest = User.last
    assert guest.guest?
    play_daily_challenge(guest)

    assert_no_difference -> { User.count } do
      post registration_path, params: { user: { name: "Zara", username: "zara_b", password: "a long secret phrase" } }
    end

    guest.reload
    assert_equal "zara_b", guest.username
    assert_equal 1, guest.current_streak
    assert_equal 2, guest.attempts.count
    assert_equal guest, User.authenticate_by(username: "zara_b", password: "a long secret phrase")
  end

  test "shows errors for a taken username" do
    assert_no_difference -> { User.count } do
      post registration_path, params: { user: { name: "Ada", username: "ada", password: "a long secret phrase" } }
    end

    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /Username has already been taken/
  end

  test "registering a guest rotates the session and keeps outstanding game tickets valid" do
    post attempts_path, params: game_upload(results: answers(*right_answers(5))), as: :json
    guest = User.last
    upload = game_upload(results: answers([ 2, 3, 6 ]))
    old_session = Session.last
    owner = response.headers.fetch("X-Player-Key")
    post registration_path, params: { user: { name: "Zara", username: "zara_b", password: "a long secret phrase" } }
    assert_redirected_to root_path
    assert_not Session.exists?(old_session.id)
    assert_equal owner, response.headers.fetch("X-Player-Key")
    post attempts_path, params: upload, as: :json
    assert_response :created
    assert_equal 2, guest.attempts.count
  end
end
