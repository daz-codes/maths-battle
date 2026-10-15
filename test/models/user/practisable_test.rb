require "test_helper"

class User::PractisableTest < ActiveSupport::TestCase
  setup { @user = users(:ada) }

  def generate(count: 150, seed: 1)
    @user.questions(count: count, random: Random.new(seed))
  end

  def key(question) = TimesTables.fact_key(question[:a], question[:b])

  test "makes the requested number of questions within the tables" do
    questions = generate
    assert_equal 150, questions.size
    assert questions.all? { |q| TimesTables.valid_question?(q[:a], q[:b]) }
  end

  test "never asks the same fact twice in a row" do
    questions = generate(count: 2000)
    questions.each_cons(2) { |x, y| assert_not_equal key(x), key(y) }
  end

  test "asks facts both ways round" do
    sevens_eights = generate(count: 5000).select { |q| key(q) == "7x8" }
    assert_includes sevens_eights, { a: 7, b: 8 }
    assert_includes sevens_eights, { a: 8, b: 7 }
  end

  test "rarely asks the 1x and 10x tables" do
    questions = generate(count: 5000)
    trivial = questions.count { |q| [ q[:a], q[:b] ].intersect?([ 1, 10 ]) }
    assert_operator trivial.fdiv(questions.size), :<, 0.05
  end

  # A fresh copy each time, as weights are worked out once per player object
  def weights = User.find(@user.id).question_weights

  test "facts with a lower percentage correct come up more often" do
    @user.fact_stats.create!(topic: "times_tables", fact: "7x8", correct_count: 1, wrong_count: 3)

    assert_operator weights[[ 7, 8 ]], :>, weights[[ 6, 8 ]] * 3

    questions = generate(count: 5000)
    assert_operator questions.count { |q| key(q) == "7x8" }, :>, questions.count { |q| key(q) == "6x8" } * 3
  end

  test "weight goes from 1 at 100% correct up to 5 at 0% correct" do
    @user.fact_stats.create!(topic: "times_tables", fact: "2x3", correct_count: 20, wrong_count: 0)
    @user.fact_stats.create!(topic: "times_tables", fact: "4x6", correct_count: 5, wrong_count: 5)
    @user.fact_stats.create!(topic: "times_tables", fact: "8x9", correct_count: 0, wrong_count: 2)

    assert_equal 1.0, weights[[ 2, 3 ]]
    assert_equal 3.0, weights[[ 4, 6 ]]
    assert_equal 5.0, weights[[ 8, 9 ]]
    assert_equal 1.0, weights[[ 2, 4 ]], "facts not asked yet start at the normal weight"
  end

  def timed_stat(fact, average_ms, correct_count: 4)
    @user.fact_stats.create!(topic: "times_tables", fact: fact, correct_count: correct_count, correct_ms: average_ms * correct_count)
  end

  test "facts answered right but slowly come up more often" do
    %w[2x3 2x4 2x5 3x4 3x5].each { timed_stat(_1, 2000) }
    timed_stat("7x8", 4000)

    assert_equal 3.0, weights[[ 7, 8 ]], "twice the typical time gets the full slow boost"
    assert_equal 1.0, weights[[ 2, 3 ]]
  end

  test "quick answers are never slow, even for a very fast player" do
    %w[2x3 2x4 2x5 3x4 3x5].each { timed_stat(_1, 600) }
    timed_stat("7x8", 1200)

    assert_equal 1.0, weights[[ 7, 8 ]]
  end

  test "one timed answer isn't enough to call a fact slow" do
    %w[2x3 2x4 2x5].each { timed_stat(_1, 2000) }
    timed_stat("7x8", 8000, correct_count: 1)

    assert_equal 1.0, weights[[ 7, 8 ]]
  end

  def play(right:, wrong:)
    Attempt.record!(user: @user, results: answers(*right_answers(right), *Array.new(wrong) { [ 7, 8, 1 ] }))
  end

  test "players doing well, and new players, get the normal mix" do
    assert_equal 0.0, User.find(@user.id).easing

    play(right: 18, wrong: 2)
    assert_equal 0.0, User.find(@user.id).easing
  end

  test "a struggling player gets more easy questions and fewer hard ones" do
    play(right: 8, wrong: 12)
    struggling = User.find(@user.id)

    assert_equal 1.0, struggling.easing
    assert_in_delta 3.0, struggling.question_weights[[ 2, 5 ]]
    assert_in_delta 1.5, struggling.question_weights[[ 3, 4 ]]
    assert_operator struggling.question_weights[[ 6, 9 ]], :<, 0.5
  end

  test "the shift eases off as recent games improve" do
    play(right: 8, wrong: 12)
    3.times { play(right: 19, wrong: 1) }

    assert_equal 0.0, User.find(@user.id).easing, "only the last few games count"
  end

  test "partway struggling gets a partial shift" do
    play(right: 13, wrong: 7) # 65%: halfway between 80% and 50%
    assert_in_delta 0.5, User.find(@user.id).easing
  end

  test "a fact comes up less as its percentage correct improves" do
    stat = @user.fact_stats.create!(topic: "times_tables", fact: "7x8", correct_count: 1, wrong_count: 3)
    before = weights[[ 7, 8 ]]

    stat.update!(correct_count: 9)
    assert_operator weights[[ 7, 8 ]], :<, before
  end
end
