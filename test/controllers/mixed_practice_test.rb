require "test_helper"

# Mixed practice: every level up to the player's, as often as they like. It took the daily challenge's place,
# so a link to the daily challenge (from a page kept for offline) is mixed practice now
class MixedPracticeTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:ada)
    unlock(@user, TimesTables, 2)
    sign_in_as @user
  end

  def mixed_upload(score:)
    get play_path("times-tables", mixed: 1)
    set = JSON.parse(css_select("[data-controller=test]").first["data-test-question-sets-value"]).first
    results = set["questions"].first(score).map { |question| question.slice("a", "b").merge("given" => question["answer"], "ms" => 1000) }
    { attempt: { topic: "times_tables", level: 2, client_id: set["id"], ticket: set["ticket"], results: results } }
  end

  test "at the player's highest level, mixing every level up to it, as often as they like" do
    2.times do
      get play_path("times-tables", mixed: 1)
      assert_select "[data-test-mode-value=mixed][data-test-level-value=2]"
    end
    assert_select "title", text: /Times tables mixed practice/
  end

  test "saved as mixed practice: no stars, no best to beat, but it keeps the streak" do
    post attempts_path, params: mixed_upload(score: 12), as: :json
    assert_response :created
    mixed = @user.attempts.last
    assert mixed.mixed?
    assert_equal 0, mixed.stars
    assert_not mixed.new_high_score
    assert @user.reload.practised_today?

    get attempt_path(mixed)
    assert_select ".label", text: /Times tables, mixed practice/
    assert_select ".results__actions a[href=?]", play_path("times-tables", mixed: 1), text: "Play again"
  end

  test "a daily challenge link is mixed practice now" do
    get play_path("times-tables", challenge: 1)
    assert_redirected_to play_path("times-tables", mixed: 1)
  end

  test "old daily challenge games still show as they were" do
    old = play_daily_challenge(@user)
    get attempt_path(old)
    assert_select ".label", text: /Times tables, daily challenge/
  end
end
