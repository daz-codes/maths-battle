require "test_helper"

class LevelsTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:ada)
    sign_in_as @user
  end

  NEEDED = User::Levelable::GOOD_GAMES_TO_LEVEL_UP

  def good_games(count, level:)
    count.times { Attempt.record!(user: @user, level: level, results: answers(*Array.new(20) { [ 2, 3, 6 ] }, ms: 1000)) }
  end

  test "home shows the levels, with locked ones padlocked, and how close the next one is" do
    good_games(1, level: 1)
    get root_path

    assert_select ".levels .levels__level[aria-current=true]", text: "1"
    assert_select ".levels__level--locked", 4
    assert_select ".levels__name", text: "Level 1: Tables 2–5"
    assert_select ".level-progress", count: 0, message: "how close the next level is shows on the results page"
    assert_select ".levels-panel > a.button--start[href=?]", play_path("times-tables")
    assert_select ".levels__level--locked svg.icon", 4
  end

  test "the results page says how close the next level is" do
    good_games(1, level: 1)
    get attempt_path(@user.attempts.last)

    assert_select ".level-progress", text: /#{NEEDED - 1} more good games at level 1 to unlock\s+Level 2: Tables 2–12/
  end

  test "levelling up is celebrated, and Play moves up to the new level" do
    good_games(NEEDED - 1, level: 1)
    patch level_path, params: { level: 1 }

    post attempts_path, params: game_upload(level: 1, results: answers(*Array.new(20) { [ 2, 3, 6 ] }, ms: 1000)), as: :json
    get response.parsed_body["url"]
    assert_select ".banner--level", text: /Level up! You've unlocked Level 2: Tables 2–12/

    get root_path
    assert_select ".levels__name", text: "Level 2: Tables 2–12"
  end

  test "Play moves up after levelling up, even if the results page is never seen (a game uploaded from offline)" do
    good_games(NEEDED - 1, level: 1)
    patch level_path, params: { level: 1 }

    post attempts_path, params: game_upload(level: 1, results: answers(*Array.new(20) { [ 2, 3, 6 ] }, ms: 1000)), as: :json
    get root_path
    assert_select ".levels__name", text: "Level 2: Tables 2–12"
  end

  test "looking at an old levelling up game again doesn't change the level picked" do
    good_games(NEEDED, level: 1)
    levelled_up = @user.attempts.find_by!(levelled_up: true)
    patch level_path, params: { level: 1 }

    get attempt_path(levelled_up)
    get root_path
    assert_select ".levels__name", text: "Level 1: Tables 2–5"
  end

  test "an easier unlocked level can be picked, and is what Play plays" do
    good_games(NEEDED, level: 1)
    patch level_path, params: { level: 1 }
    get root_path
    assert_select ".levels__name", text: "Level 1: Tables 2–5"

    get play_path("times-tables")
    assert_select "[data-test-level-value=1]"
  end

  test "a locked level can't be picked or played" do
    patch level_path, params: { level: 4 }
    get play_path("times-tables", level: 4)
    assert_select "[data-test-level-value=1]"
  end

  test "the stats page uses the same topic and level chooser, leading to stats" do
    good_games(NEEDED, level: 1)
    get stats_path("times-tables", level: 1)

    assert_select "form.topic-picker[action=?][method=get] select[name=topic] option[selected]", stats_path, text: /Times tables/
    assert_select "form[action=?][method=get] input[name=level][value=2]", stats_path("times-tables")
    assert_select ".levels .levels__level[aria-current=true]", text: "1"
    assert_select ".levels__level--locked", 3
    assert_select ".levels__name", text: "Level 1: Tables 2–5"

    get stats_path("times-tables", level: 2)
    assert_select ".levels .levels__level[aria-current=true]", text: "2"
    assert_equal 2, @user.unlocked_level(TimesTables), "looking at stats doesn't change anything"
  end

  test "the keypad grows a decimal point, then a minus sign" do
    (1..4).each { |level| good_games(NEEDED, level: level) }

    get play_path("times-tables", level: 3)
    assert_select ".keypad__key--extra", count: 0

    get play_path("times-tables", level: 4)
    assert_select ".keypad__key--extra", text: "."

    get play_path("times-tables", level: 5)
    assert_select ".keypad--wide .keypad__key--extra", 2
    assert_select ".keypad__key[data-digit='-']", text: "−"
  end

  test "a game of decimals and negatives is checked on the server" do
    (1..4).each { |level| good_games(NEEDED, level: level) }
    results = [ { a: "0.7", b: "-3000", given: "-2100", ms: 3000 }, { a: "-0.4", b: "0.6", given: "-0.24", ms: 3000 }, { a: "0.4", b: "0.6", given: "0.240", ms: 3000 } ]

    post attempts_path, params: game_upload(level: 5, results: results), as: :json
    assert_response :created
    assert_equal [ true, true, false ], @user.attempts.last.results.map { _1["correct"] }, "0.240 isn't how 0.24 is written"

    post attempts_path, params: game_upload(level: 3, results: [ { a: "-7", b: "8", given: "-56", ms: 1000 } ]), as: :json
    assert_response :unprocessable_entity, "negatives aren't part of level 3"
  end
end
