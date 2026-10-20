require "test_helper"

# Times tables' daily challenge: once a day, every level up to the player's, its own best
class DailyChallengeTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:ada)
    sign_in_as @user
    Attempt.record!(user: @user, results: answers(*Array.new(10) { [ 2, 3, 6 ] }, ms: 1000)) # bronze: level 2 unlocked
  end

  def challenge_upload(score:)
    get play_path("times-tables", challenge: 1)
    sets = JSON.parse(css_select("[data-controller=test]").first["data-test-question-sets-value"])
    set = sets.first
    results = set["questions"].first(score).map { |question| question.slice("a", "b").merge("given" => question["answer"], "ms" => 1000) }
    { attempt: { topic: "times_tables", level: 2, client_id: set["id"], ticket: set["ticket"], results: results } }
  end

  test "the daily challenge is at the player's highest level, mixing every level up to it" do
    get play_path("times-tables", challenge: 1)
    assert_select "[data-test-mode-value=challenge][data-test-level-value=2]"
    assert_select "title", text: /Times tables daily challenge/
  end

  test "it's saved as the daily challenge, because its ticket says so" do
    post attempts_path, params: challenge_upload(score: 12), as: :json
    assert_response :created

    challenge = @user.attempts.last
    assert challenge.daily_challenge?
    assert_nil challenge.medal
    assert_equal 0, @user.best_score(TimesTables, 2), "a daily challenge isn't a level 2 game"
    assert_equal 12, @user.best_daily_challenge(TimesTables)
  end

  test "a level's practice can't be passed off as the daily challenge" do
    post attempts_path, params: game_upload(level: 2, results: answers([ 7, 8, 56 ]), mode: "challenge"), as: :json
    assert_response :created
    assert_not @user.attempts.last.daily_challenge?
  end

  test "once a day: the home page then shows how it went, and the game won't start again" do
    another_tab = challenge_upload(score: 5)
    post attempts_path, params: challenge_upload(score: 12), as: :json
    challenge = @user.attempts.last

    get root_path
    assert_select "a.daily-done[href=?]", attempt_path(challenge), text: "✅ Challenge done today: 12"
    assert_select "a.button--challenge", count: 0

    get play_path("times-tables", challenge: 1)
    assert_redirected_to root_path

    post attempts_path, params: another_tab, as: :json
    assert_response :unprocessable_entity, "a second one started before the first was saved"
    assert_equal "Today's daily challenge is already done", response.parsed_body["error"]
  end

  test "tomorrow there's a new one" do
    post attempts_path, params: challenge_upload(score: 12), as: :json

    travel 1.day do
      get root_path
      assert_select "a.button--challenge[href=?]", play_path("times-tables", challenge: 1), text: /⭐ Daily challenge/
    end
  end

  test "its results page says it's the daily challenge, and offers practice rather than playing again" do
    post attempts_path, params: challenge_upload(score: 12), as: :json
    get response.parsed_body["url"]

    assert_select ".label", text: /Times tables, daily challenge/
    assert_select ".results__actions a[href=?]", play_path("times-tables", level: 2), text: "Practise level 2"
    assert_select ".level-progress", count: 0
  end

  test "every topic has its own daily challenge" do
    post attempts_path, params: challenge_upload(score: 12), as: :json

    get play_path("equations", challenge: 1)
    assert_select "[data-test-mode-value=challenge][data-test-level-value=1]", message: "times tables' doesn't use up equations'"
  end

  test "a signed challenge and its retry still save after another game unlocks a level" do
    upload = challenge_upload(score: 3)
    unlock(@user, TimesTables, 3)

    post attempts_path, params: upload, as: :json
    assert_response :created
    url = response.parsed_body["url"]
    assert_equal 2, @user.attempts.last.level

    unlock(@user, TimesTables, 4)
    assert_no_difference -> { Attempt.count } do
      post attempts_path, params: upload, as: :json
    end
    assert_response :created
    assert_equal url, response.parsed_body["url"]
  end

  test "an unanswered challenge leaves today's challenge available and earns no streak" do
    travel_to Time.zone.local(2026, 11, 1, 12) do
      assert_no_difference -> { Attempt.count } do
        post attempts_path, params: challenge_upload(score: 0), as: :json
      end
      assert_response :unprocessable_entity
      assert_match /at least one question/, response.parsed_body["error"]
      assert_nil @user.daily_challenge_on(TimesTables)
      assert_equal 0, @user.reload.streak
      get play_path("times-tables", challenge: 1)
      assert_response :success
    end
  end

  test "legacy unanswered challenges do not consume the day or keep a streak" do
    travel_to Time.zone.local(2026, 11, 1, 12) do
      @user.attempts.create!(mode: "challenge", results: [])
      assert_nil @user.daily_challenge_on(TimesTables)
      assert_equal 0, @user.reload.streak
      post attempts_path, params: challenge_upload(score: 1), as: :json
      assert_response :created
      assert_equal 1, @user.reload.streak
    end
  end

  test "mixed practice opens up once the day's challenge is done: the same mix, as often as they like" do
    get play_path("times-tables", mixed: 1)
    assert_redirected_to root_path
    get root_path
    assert_select "a.button--mixed", count: 0

    post attempts_path, params: challenge_upload(score: 12), as: :json
    get root_path
    assert_select "a.button--mixed[href=?]", play_path("times-tables", mixed: 1), text: "🔀 Mixed practice"

    2.times do
      get play_path("times-tables", mixed: 1)
      assert_select "[data-test-mode-value=mixed][data-test-level-value=2]"
    end
    set = JSON.parse(css_select("[data-controller=test]").first["data-test-question-sets-value"]).first
    results = set["questions"].first(8).map { |question| question.slice("a", "b").merge("given" => question["answer"], "ms" => 1000) }
    post attempts_path, params: { attempt: { topic: "times_tables", level: 2, client_id: set["id"], ticket: set["ticket"], results: results } }, as: :json
    mixed = @user.attempts.last
    assert mixed.mixed?
    assert_nil mixed.medal
    assert_not mixed.new_high_score
    get attempt_path(mixed)
    assert_select ".label", text: /Times tables, mixed practice/
    assert_select ".results__actions a[href=?]", play_path("times-tables", mixed: 1), text: "Play again"
  end
end
