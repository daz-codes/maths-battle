require "test_helper"

class GuestPlayTest < ActionDispatch::IntegrationTest
  test "a visitor can take the test" do
    get play_path("times-tables")
    assert_response :success
  end

  test "the first saved test makes a guest account with a session on this device" do
    assert_difference -> { User.count } => 1, -> { Session.count } => 1 do
      post attempts_path, params: game_upload(results: answers(*right_answers(5))), as: :json
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
    post attempts_path, params: game_upload(results: answers(*right_answers(5))), as: :json

    assert_no_difference -> { User.count } do
      post attempts_path, params: game_upload(results: answers(*right_answers(6))), as: :json
    end
    assert_equal 2, User.last.attempts.count
    assert_equal 6, User.last.best_score(TimesTables, 1)
  end

  test "a visitor's footer offers sign in and sign up beside their picture, then home, awards and stats" do
    choose_topic
    get root_path

    assert_select ".site-footer a.site-footer__player[aria-label=Settings][href=?]", edit_profile_path
    assert_select ".site-footer .site-footer__auth a[href=?]", new_session_path, text: "Sign in"
    assert_select ".site-footer .site-footer__auth a[href=?]", new_registration_path, text: "Sign up"
    assert_select ".site-footer > a", 3
    assert_select ".site-footer > a:first-of-type[href=?]", root_path, text: "Home"
  end

  test "visiting pages doesn't create guests" do
    assert_no_difference -> { User.count } do
      get root_path
      get play_path("times-tables")
      get edit_profile_path
    end
  end

  test "signing in as a real user ends the guest session" do
    post attempts_path, params: game_upload(results: answers(*right_answers(5))), as: :json
    guest_session = Session.last

    post session_path, params: { username: "ada", password: "password" }
    assert_not Session.exists?(guest_session.id)
    assert_equal users(:ada), Session.last.user
  end

  test "saving settings over and over can't make endless guests" do
    with_rate_limiting do
      assert_difference -> { User.count } => 10 do
        11.times do
          cookies.delete("session_id")
          patch profile_path, params: { user: { theme: "dark" } }
        end
      end
    end

    assert_redirected_to edit_profile_path
    follow_redirect!
    assert_select ".flash--alert", text: "Try again later."
  end

  private
    # The test cache store keeps nothing, so rate limits never kick in without a real one for a moment
    def with_rate_limiting
      store = ActiveSupport::Cache::MemoryStore.new
      Rails.cache.define_singleton_method(:increment) { |*args, **options| store.increment(*args, **options) }
      yield
    ensure
      Rails.cache.singleton_class.remove_method(:increment)
    end
end
