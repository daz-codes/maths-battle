require "test_helper"

# Times tables levels: practise a level for a medal, and a bronze unlocks the next one
class LevelsTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:ada)
    sign_in_as @user
  end

  def practise(level:, score:)
    Attempt.record!(user: @user, level: level, results: answers(*Array.new(score) { [ 2, 3, 6 ] }, ms: 1000))
  end

  test "home shows the levels, with locked ones padlocked, medals on the ones that have them, and what's next" do
    practise(level: 1, score: 22)
    get root_path

    assert_select ".levels .levels__level[aria-current=true]", text: /2/, message: "the bronze unlocked level 2, which Play goes to"
    assert_select ".levels .levels__level .levels__medal[aria-label=Silver]", text: "🥈"
    assert_select ".levels__level--locked", 3
    assert_select ".levels__name", text: "Level 2: Tables 2–12"
    assert_select ".levels__medal-line", text: "Score 10 for 🥉 bronze and unlock level 3"
    assert_select ".levels-panel > a.button--start[href=?]", play_path("times-tables", challenge: 1), text: "⭐ Daily challenge"
    assert_select ".levels-panel > a.button--practise[href=?]", play_path("times-tables", level: 2), text: "Practise level 2"
  end

  test "a level's best medal and the next to aim for" do
    practise(level: 1, score: 22)
    patch level_path, params: { level: 1 }
    get root_path
    assert_select ".levels__medal-line", text: "🥈 Silver · best 22 · 30 for gold"
  end

  test "the results page says what the next medal needs" do
    practise(level: 1, score: 12)
    get attempt_path(@user.attempts.last)

    assert_select ".level-progress", text: "🥉 Bronze · best 12 · 20 for silver"
  end

  test "a bronze is celebrated as a level up, and Play moves up to the new level" do
    practise(level: 1, score: 9)
    patch level_path, params: { level: 1 }

    post attempts_path, params: game_upload(level: 1, results: answers(*Array.new(10) { [ 2, 3, 6 ] }, ms: 1000)), as: :json
    get response.parsed_body["url"]
    assert_select ".banner--level", text: /Level up! You've unlocked Level 2: Tables 2–12/

    get root_path
    assert_select ".levels__name", text: "Level 2: Tables 2–12"
  end

  test "a better medal at a level is celebrated" do
    practise(level: 1, score: 12)
    post attempts_path, params: game_upload(level: 1, results: answers(*Array.new(21) { [ 2, 3, 6 ] }, ms: 1000)), as: :json
    get response.parsed_body["url"]

    assert_select ".banner--medal", text: "🥈 Silver medal for level 1!"
  end

  test "Play moves up after levelling up, even if the results page is never seen (a game uploaded from offline)" do
    patch level_path, params: { level: 1 }

    post attempts_path, params: game_upload(level: 1, results: answers(*Array.new(10) { [ 2, 3, 6 ] }, ms: 1000)), as: :json
    get root_path
    assert_select ".levels__name", text: "Level 2: Tables 2–12"
  end

  test "looking at an old levelling up game again doesn't change the level picked" do
    levelled_up = practise(level: 1, score: 10)
    patch level_path, params: { level: 1 }

    get attempt_path(levelled_up)
    get root_path
    assert_select ".levels__name", text: "Level 1: Tables 2–5"
  end

  test "an easier unlocked level can be picked, and is what Practise plays" do
    practise(level: 1, score: 10)
    patch level_path, params: { level: 1 }
    get root_path
    assert_select ".levels__name", text: "Level 1: Tables 2–5"
    assert_select "a.button--practise[href=?]", play_path("times-tables", level: 1), text: "Practise level 1"

    get play_path("times-tables")
    assert_select "[data-test-level-value=1]"
    assert_select "[data-test-daily-challenge-value=false]"
  end

  test "a locked level can't be picked or played" do
    patch level_path, params: { level: 4 }
    get play_path("times-tables", level: 4)
    assert_select "[data-test-level-value=1]"
  end

  test "the stats page uses the same topic and level chooser, leading to stats" do
    practise(level: 1, score: 10)
    get stats_path("times-tables", level: 1)

    assert_select "form.topic-picker[action=?][method=get] select[name=topic] option[selected]", stats_path, text: /Times tables/
    assert_select "form[action=?][method=get] input[name=level][value=2]", stats_path("times-tables")
    assert_select ".levels .levels__level[aria-current=true]", text: /1/
    assert_select ".levels__level--locked", 3
    assert_select ".levels__name", text: "Level 1: Tables 2–5"
    assert_select ".levels-panel > a.button--practise[href=?]", play_path("times-tables", level: 1)

    get stats_path("times-tables", level: 2)
    assert_select ".levels .levels__level[aria-current=true]", text: /2/
    assert_equal 2, @user.unlocked_level(TimesTables), "looking at stats doesn't change anything"
  end

  test "every topic has medals, practice and a daily challenge, with its own medal scores" do
    patch topic_path, params: { topic: "equations" }
    get root_path

    assert_select ".levels__medal-line", text: "Score 6 for 🥉 bronze and unlock level 2"
    assert_select ".levels-panel > a.button--start[href=?]", play_path("equations", challenge: 1)
    assert_select ".levels-panel > a.button--practise[href=?]", play_path("equations", level: 1)
  end

  test "the keypad grows a decimal point, then a minus sign" do
    (1..4).each { |level| practise(level: level, score: 10) }

    get play_path("times-tables", level: 3)
    assert_select ".keypad__key--extra", count: 0

    get play_path("times-tables", level: 4)
    assert_select ".keypad__key--extra", text: "."

    get play_path("times-tables", level: 5)
    assert_select ".keypad--wide .keypad__key--extra", 2
    assert_select ".keypad__key[data-digit='-']", text: "−"
  end

  test "a game of decimals and negatives is checked on the server" do
    (1..4).each { |level| practise(level: level, score: 10) }
    results = [ { a: "0.7", b: "-3000", given: "-2100", ms: 3000 }, { a: "-0.4", b: "0.6", given: "-0.24", ms: 3000 }, { a: "0.4", b: "0.6", given: "0.240", ms: 3000 } ]

    post attempts_path, params: game_upload(level: 5, results: results), as: :json
    assert_response :created
    assert_equal [ true, true, false ], @user.attempts.last.results.map { _1["correct"] }, "0.240 isn't how 0.24 is written"

    post attempts_path, params: game_upload(level: 3, results: [ { a: "-7", b: "8", given: "-56", ms: 1000 } ]), as: :json
    assert_response :unprocessable_entity, "negatives aren't part of level 3"
  end
end
