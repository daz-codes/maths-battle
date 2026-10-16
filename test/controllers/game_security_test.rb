require "test_helper"

class GameSecurityTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:ada) }

  test "a game cannot be uploaded to a different account or after signing out" do
    upload = game_upload(results: answers([ 2, 3, 6 ]))
    post session_path, params: { username: "bob", password: "password" }
    assert_no_difference -> { Attempt.count } do
      post attempts_path, params: upload, as: :json
    end
    assert_response :unprocessable_entity

    delete session_path
    assert_no_difference -> { User.count } do
      post attempts_path, params: upload, as: :json
    end
    assert_response :unprocessable_entity
  end

  test "only the issued questions in order are accepted" do
    get play_path("times-tables")
    set = JSON.parse(css_select("[data-test-question-sets-value]").first["data-test-question-sets-value"]).first
    question = set.fetch("questions").first.except("text", "answer")
    upload = { attempt: { topic: "times_tables", level: 1, client_id: set["id"], ticket: set["ticket"],
      results: [ question.merge("given" => "999", "ms" => 1000, "a" => "999") ] } }
    assert_no_difference -> { Attempt.count } do
      post attempts_path, params: upload, as: :json
    end
    assert_response :unprocessable_entity
  end

  test "a used ticket cannot be replayed with a new client id" do
    upload = game_upload(results: answers([ 2, 3, 6 ]))
    post attempts_path, params: upload, as: :json
    assert_response :created
    upload[:attempt][:client_id] = "another-game"
    assert_no_difference -> { Attempt.count } do
      post attempts_path, params: upload, as: :json
    end
    assert_response :unprocessable_entity
  end

  test "expired and unsigned games are refused without creating guests" do
    upload = game_upload(results: answers([ 2, 3, 6 ]))
    travel Session::LIFETIME + 1.day do
      assert_no_difference -> { User.count } do
        post attempts_path, params: upload, as: :json
      end
      assert_response :unprocessable_entity
    end
    upload[:attempt].delete(:ticket)
    post attempts_path, params: upload, as: :json
    assert_response :unprocessable_entity
  end

  test "the CSP permits the importmap with a nonce and blocks untrusted scripts" do
    get root_path
    policy = response.headers.fetch("Content-Security-Policy")
    nonce = css_select("meta[name=csp-nonce]").first["content"]
    assert_includes policy, "'nonce-#{nonce}'"
    assert_includes policy, "object-src 'none'"
    assert_includes policy, "frame-ancestors 'none'"
    assert_select "script[type=importmap][nonce=?]", nonce
  end

  test "a ticket expires while the player's session is still active" do
    upload = game_upload(results: answers([ 2, 3, 6 ]))
    travel 31.days do
      assert_no_difference -> { Attempt.count } do
        post attempts_path, params: upload, as: :json
      end
      assert_response :unprocessable_entity
    end
  end

  test "login rotates the session and game uploads still require its current CSRF token" do
    ActionController::Base.allow_forgery_protection = true
    get new_session_path
    token = css_select('meta[name="csrf-token"]').first["content"]
    post session_path, params: { username: "ada", password: "password", authenticity_token: token }
    assert_redirected_to root_path
    get play_path("times-tables")
    token = css_select('meta[name="csrf-token"]').first["content"]
    set = JSON.parse(css_select("[data-test-question-sets-value]").first["data-test-question-sets-value"]).first
    question = set["questions"].first
    upload = { attempt: { topic: "times_tables", level: 1, client_id: set["id"], ticket: set["ticket"],
      results: [ question.except("text", "answer").merge("given" => question["answer"], "ms" => 1000) ] } }
    post attempts_path, params: upload, as: :json
    assert_response :unprocessable_entity
    post attempts_path, params: upload, headers: { "X-CSRF-Token" => token }, as: :json
    assert_response :created
  ensure
    ActionController::Base.allow_forgery_protection = false
  end
end
