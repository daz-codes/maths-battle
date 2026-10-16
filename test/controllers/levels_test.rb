require "test_helper"

class LevelsTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:ada)
    sign_in_as @user
  end

  def good_games(count, level:)
    count.times { Attempt.record!(user: @user, level: level, results: answers(*Array.new(20) { [ 2, 3, 6 ] }, ms: 1000)) }
  end

  test "home shows the levels, with locked ones padlocked, and how close the next one is" do
    good_games(2, level: 1)
    get root_path

    assert_select ".levels .levels__level[aria-current=true]", text: "1"
    assert_select ".levels__level--locked", 4
    assert_select ".levels__name", text: "Level 1: Tables 2–5"
    assert_select ".level-progress", text: /3 more good games at level 1 to unlock\s+Level 2: Tables 2–12/
  end

  test "levelling up is celebrated, and Play moves up to the new level" do
    good_games(4, level: 1)
    patch level_path, params: { level: 1 }

    post attempts_path, params: { attempt: { level: 1, results: answers(*Array.new(20) { [ 2, 3, 6 ] }, ms: 1000) } }, as: :json
    get response.parsed_body["url"]
    assert_select ".banner--level", text: /Level up! You've unlocked Level 2: Tables 2–12/

    get root_path
    assert_select ".levels__name", text: "Level 2: Tables 2–12"
  end

  test "an easier unlocked level can be picked, and is what Play plays" do
    good_games(5, level: 1)
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

  test "the keypad grows a decimal point, then a minus sign" do
    (1..4).each { |level| good_games(5, level: level) }

    get play_path("times-tables", level: 3)
    assert_select ".keypad__key--extra", count: 0

    get play_path("times-tables", level: 4)
    assert_select ".keypad__key--extra", text: "."

    get play_path("times-tables", level: 5)
    assert_select ".keypad--wide .keypad__key--extra", 2
    assert_select ".keypad__key[data-digit='-']", text: "−"
  end

  test "a game of decimals and negatives is checked on the server" do
    (1..4).each { |level| good_games(5, level: level) }
    results = [ { a: "0.7", b: "-3000", given: "-2100", ms: 3000 }, { a: "-0.4", b: "0.6", given: "-0.24", ms: 3000 }, { a: "0.4", b: "0.6", given: "0.240", ms: 3000 } ]

    post attempts_path, params: { attempt: { level: 5, results: results } }, as: :json
    assert_response :created
    assert_equal [ true, true, false ], @user.attempts.last.results.map { _1["correct"] }, "0.240 isn't how 0.24 is written"

    post attempts_path, params: { attempt: { level: 3, results: [ { a: "-7", b: "8", given: "-56", ms: 1000 } ] } }, as: :json
    assert_response :unprocessable_entity, "negatives aren't part of level 3"
  end
end
