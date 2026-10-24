require "test_helper"

# Times tables levels: practise a level for stars, and the first star unlocks the next one
class LevelsTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:ada)
    sign_in_as @user
  end

  # A game with so many right
  def practise(level:, score:)
    Attempt.record!(user: @user, level: level, results: answers(*Array.new(score) { [ 2, 3, 6 ] }, ms: 1000))
  end

  # What that many right scores
  def points(right)
    Attempt.new(topic: "times_tables", results: answers(*Array.new(right) { [ 2, 3, 6 ] }, ms: 1000).map(&:deep_stringify_keys).map { _1.merge("correct" => true) }).points
  end

  test "home shows the levels, with locked ones padlocked, stars on the ones that have them, and what's next" do
    practise(level: 1, score: 12)
    get practice_path

    assert_select ".levels .levels__level[aria-current=true]", text: /2/, message: "the bronze unlocked level 2, which Play goes to"
    assert_select ".levels .levels__level .stars[aria-label='2 of 3 stars']"
    assert_select ".levels__level--locked", 3
    assert_select ".levels__name", text: "Level 2: Tables 2–12"
    assert_select ".levels__progress", text: "Get 5 right for a and unlock level 3"
    assert_select ".levels__progress .icon--star"
    assert_select "a.button--play[href=?]", play_path("times-tables", level: 2), text: /Play level 2/
    assert_select ".levels-panel > a.button--mixed[href=?]", play_path("times-tables", mixed: 1)
  end

  test "a level's stars and the next to aim for" do
    practise(level: 1, score: 12)
    patch level_path, params: { level: 1 }
    get practice_path
    assert_select ".levels__progress", text: "Best: #{points(12)} · 20 right for 3 stars"
    assert_select ".levels__progress .stars", count: 0, message: "the stars are on the level's circle"
    assert_select ".levels__level .stars[aria-label='2 of 3 stars']"
  end

  test "the results page says what the next star needs" do
    practise(level: 1, score: 7)
    get attempt_path(@user.attempts.last)

    assert_select ".level-progress", text: "Best: #{points(7)} · 10 right for 2 stars"
    assert_select ".level-progress .stars", count: 0
  end

  test "a bronze is celebrated as a level up, and Play moves up to the new level" do
    practise(level: 1, score: 4)
    patch level_path, params: { level: 1 }

    post attempts_path, params: game_upload(level: 1, results: answers(*Array.new(5) { [ 2, 3, 6 ] }, ms: 1000)), as: :json
    get response.parsed_body["url"]
    assert_select ".banner--level[data-controller~=fanfare]", text: /Level up! You've unlocked Level 2: Tables 2–12/

    get practice_path
    assert_select ".levels__name", text: "Level 2: Tables 2–12"
  end

  test "more stars at a level are celebrated" do
    practise(level: 1, score: 6)
    post attempts_path, params: game_upload(level: 1, results: answers(*Array.new(11) { [ 2, 3, 6 ] }, ms: 1000)), as: :json
    get response.parsed_body["url"]

    assert_select ".banner--stars", text: /2 stars for level 1!/
  end

  test "Play moves up after levelling up, even if the results page is never seen (a game uploaded from offline)" do
    patch level_path, params: { level: 1 }

    post attempts_path, params: game_upload(level: 1, results: answers(*Array.new(10) { [ 2, 3, 6 ] }, ms: 1000)), as: :json
    get practice_path
    assert_select ".levels__name", text: "Level 2: Tables 2–12"
  end

  test "looking at an old levelling up game again doesn't change the level picked" do
    levelled_up = practise(level: 1, score: 10)
    patch level_path, params: { level: 1 }

    get attempt_path(levelled_up)
    get practice_path
    assert_select ".levels__name", text: "Level 1: Tables 2–5"
  end

  test "an easier unlocked level can be picked, and is what Practise plays" do
    practise(level: 1, score: 10)
    patch level_path, params: { level: 1 }
    get practice_path
    assert_select ".levels__name", text: "Level 1: Tables 2–5"
    assert_select "a.button--play[href=?]", play_path("times-tables", level: 1), text: /Play level 1/

    get play_path("times-tables")
    assert_select "[data-test-level-value=1]"
    assert_select "[data-test-mode-value=practice]"
  end

  test "a locked level can't be picked or played" do
    patch level_path, params: { level: 4 }
    get play_path("times-tables", level: 4)
    assert_select "[data-test-level-value=1]"
  end

  test "the stats page uses the same topic and level chooser, leading to stats" do
    practise(level: 1, score: 10)
    get stats_path("times-tables", level: 1)

    assert_select ".current-topic__name", text: "Times tables"
    assert_select ".button--play", count: 0, message: "the big Play is on the home page, under the streak"
    assert_select "form[action=?][method=get] input[name=level][value=2]", stats_path("times-tables")
    assert_select ".levels .levels__level[aria-current=true]", text: /1/
    assert_select ".levels__level--locked", 3
    assert_select ".levels__name", text: "Level 1: Tables 2–5"
    assert_select ".levels-panel > a.button--practise[href=?]", play_path("times-tables", level: 1), text: "Play level 1"

    get stats_path("times-tables", level: 2)
    assert_select ".levels .levels__level[aria-current=true]", text: /2/
    assert_equal 2, @user.unlocked_level(TimesTables), "looking at stats doesn't change anything"
  end

  test "every topic has stars and Play, at 5, 10 and 20" do
    patch topic_path, params: { topic: "equations" }
    get practice_path

    assert_select ".levels__progress", text: "Get 5 right for a and unlock level 2"
    assert_select "a.button--play[href=?]", play_path("equations", level: 1)
  end

  test "the keypad grows a decimal point, and never a minus sign" do
    (1..4).each { |level| practise(level: level, score: 10) }

    get play_path("times-tables", level: 3)
    assert_select ".keypad__key--extra", count: 0

    [ 4, 5 ].each do |level|
      get play_path("times-tables", level: level)
      assert_select ".keypad__key--extra", 1
      assert_select ".keypad__key--extra", text: "."
    end
  end

  test "games from when times tables had negatives are still read: the next results page shows" do
    old = { "a" => "-7", "b" => "8", "given" => "-55", "correct" => false, "ms" => 2000 }
    @user.attempts.create!(topic: "times_tables", level: 5, results: [ old ] * 3, played_at: 1.day.ago)
    attempt = practise(level: 1, score: 6)

    get attempt_path(attempt)
    assert_response :success
    assert_equal "−7 × 8 = −56", TimesTables.label(old)
    assert_equal "7x8", TimesTables.fact_key(old)
    assert_raises(Attempt::Invalid) { TimesTables.clean_result(old, level: 5) }
  end

  test "zeroes, then decimals only, then both, are checked on the server; negatives are their own topic" do
    (1..4).each { |level| practise(level: level, score: 10) }
    results = [ { a: "0.7", b: "3000", given: "2100", ms: 3000 }, { a: "0.4", b: "0.6", given: "0.24", ms: 3000 }, { a: "0.4", b: "0.6", given: "0.240", ms: 3000 } ]

    post attempts_path, params: game_upload(level: 5, results: results), as: :json
    assert_response :created
    assert_equal [ true, true, false ], @user.attempts.last.results.map { _1["correct"] }, "0.240 isn't how 0.24 is written"

    post attempts_path, params: game_upload(level: 4, results: [ { a: "0.7", b: "3000", given: "2100", ms: 1000 } ]), as: :json
    assert_response :unprocessable_entity, "zeroes and decimals together are level 5"
    post attempts_path, params: game_upload(level: 5, results: [ { a: "-7", b: "8", given: "-56", ms: 1000 } ]), as: :json
    assert_response :unprocessable_entity, "no negatives in times tables"
  end

  test "beating your best score: by how much, or how close it was, then how many were right against the most" do
    practise(level: 1, score: 12)
    get attempt_path(practise(level: 1, score: 15))
    assert_select ".best-line--new", text: "#{points(15)}, up from #{points(12)}"
    assert_select ".best-line--right", text: "15 right, your most yet!"

    get attempt_path(practise(level: 1, score: 14))
    assert_select ".best-line", text: "So close! #{points(15) - points(14) + 1} more to beat your best of #{points(15)}"
    assert_select ".best-line--right", text: "14 right · your most is 15"
    get attempt_path(practise(level: 1, score: 15))
    assert_select ".best-line", text: "Level with your best of #{points(15)}! A little more next time!"
    assert_select ".best-line--right", text: "15 right, level with your most"
    get attempt_path(practise(level: 1, score: 6))
    assert_select ".best-line", text: "#{points(15) - points(6) + 1} more to beat your best of #{points(15)}"
  end

  test "a first game has no best to compare with, and only practice has a best" do
    get attempt_path(practise(level: 1, score: 7))
    assert_select ".best-line", count: 0
  end

  test "a level's practice game knows the best to beat; mixed practice and reviews don't" do
    practise(level: 1, score: 12)
    get play_path("times-tables", level: 1)
    assert_select "[data-test-best-value=?]", points(12).to_s
    assert_select ".test__best", text: "Best #{points(12)}"

    get play_path("times-tables", level: 2)
    assert_select "[data-test-best-value=0]"
    assert_select ".test__best", count: 0
    get play_path("times-tables", mixed: 1)
    assert_select "[data-test-best-value=0]"
  end

  test "beating a best is a big celebration, and new awards spin in" do
    practise(level: 1, score: 8)
    get attempt_path(practise(level: 1, score: 12))
    assert_select ".banner[data-controller~=confetti][data-controller~=fanfare][data-confetti-big-value=true]"
    assert_select "main[data-controller=reveal]"
    assert_select ".banner[data-reveal-target=item]", 1, "the banner spins in first"
    assert_select ".badges--new .badge[data-reveal-target=item]", message: "then each award"

    get attempt_path(practise(level: 1, score: 13))
    assert_select "[data-confetti-big-value=true]", text: /New high score/
  end

  test "a first game's high score is a normal celebration" do
    get attempt_path(practise(level: 1, score: 3))
    assert_select ".banner[data-confetti-big-value=false]", text: /New high score/
  end
end
