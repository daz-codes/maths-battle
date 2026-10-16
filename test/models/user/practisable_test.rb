require "test_helper"

class User::PractisableTest < ActiveSupport::TestCase
  setup { @user = users(:ada) }

  # Level 2 is the full 2–12 tables
  def generate(count: 150, seed: 1, level: 2)
    @user.questions(level: level, count: count, random: Random.new(seed))
  end

  def stat(fact, **counts) = @user.fact_stats.create!(topic: "times_tables", level: 2, fact: fact, **counts)

  def key(question) = TimesTables.fact_key(question.slice(:a, :b).stringify_keys)

  test "makes the requested number of questions within the tables" do
    questions = generate
    assert_equal 150, questions.size
    assert questions.all? { |q| TimesTables::FACTORS.cover?(q[:a].to_i) && TimesTables::FACTORS.cover?(q[:b].to_i) }
  end

  test "never asks the same fact twice in a row" do
    questions = generate(count: 2000)
    questions.each_cons(2) { |x, y| assert_not_equal key(x), key(y) }
  end

  test "asks facts both ways round" do
    sevens_eights = generate(count: 5000).select { |q| key(q) == "7x8" }.map { |q| q.slice(:a, :b) }
    assert_includes sevens_eights, { a: "7", b: "8" }
    assert_includes sevens_eights, { a: "8", b: "7" }
  end

  test "rarely asks the 1x and 10x tables" do
    questions = generate(count: 5000)
    trivial = questions.count { |q| [ q[:a], q[:b] ].intersect?(%w[ 1 10 ]) }
    assert_operator trivial.fdiv(questions.size), :<, 0.05
  end

  # A fresh copy each time, as weights are worked out once per player object
  def weights = User.find(@user.id).question_weights(TimesTables, 2)

  test "facts with a lower percentage correct come up more often" do
    stat("7x8", correct_count: 1, wrong_count: 3)

    assert_operator weights["7x8"], :>, weights["6x8"] * 3

    questions = generate(count: 5000)
    assert_operator questions.count { |q| key(q) == "7x8" }, :>, questions.count { |q| key(q) == "6x8" } * 3
  end

  test "weight goes from 1 at 100% correct up to 5 at 0% correct" do
    stat("2x3", correct_count: 20, wrong_count: 0)
    stat("4x6", correct_count: 5, wrong_count: 5)
    stat("8x9", correct_count: 0, wrong_count: 2)

    assert_equal 1.0, weights["2x3"]
    assert_equal 3.0, weights["4x6"]
    assert_equal 5.0, weights["8x9"]
    assert_equal 1.0, weights["2x4"], "facts not asked yet start at the normal weight"
  end

  def timed_stat(fact, average_ms, correct_count: 4)
    stat(fact, correct_count: correct_count, correct_ms: average_ms * correct_count)
  end

  test "facts answered right but slowly come up more often" do
    %w[2x3 2x4 2x5 3x4 3x5].each { timed_stat(_1, 2000) }
    timed_stat("7x8", 4000)

    assert_equal 3.0, weights["7x8"], "twice the typical time gets the full slow boost"
    assert_equal 1.0, weights["2x3"]
  end

  test "quick answers are never slow, even for a very fast player" do
    %w[2x3 2x4 2x5 3x4 3x5].each { timed_stat(_1, 600) }
    timed_stat("7x8", 1200)

    assert_equal 1.0, weights["7x8"]
  end

  test "one timed answer isn't enough to call a fact slow" do
    %w[2x3 2x4 2x5].each { timed_stat(_1, 2000) }
    timed_stat("7x8", 8000, correct_count: 1)

    assert_equal 1.0, weights["7x8"]
  end

  # Games at level 1 (tables 2–5), where a new player starts
  def play(right:, wrong:)
    Attempt.record!(user: @user, results: answers(*right_answers(right), *Array.new(wrong) { [ 4, 8, 1 ] }))
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
    assert_in_delta 3.0, struggling.question_weights(TimesTables, 1)["2x5"]
    assert_in_delta 1.5, struggling.question_weights(TimesTables, 1)["3x4"]
    assert_operator struggling.question_weights(TimesTables, 1)["2x9"], :<, 0.5
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

  test "level 1 only asks the 2 to 5 times tables" do
    assert generate(count: 2000, level: 1).all? { |q| [ q[:a], q[:b] ].map(&:to_i).intersect?([ 2, 3, 4, 5 ]) }
  end

  test "stats are kept per level, so a hard fact at one level doesn't weigh on another" do
    stat("7x8", correct_count: 0, wrong_count: 5)

    assert_operator weights["7x8"], :>, 4
    assert_equal 1.0, User.find(@user.id).question_weights(TimesTables, 3)["7x8"]
  end

  test "a fact comes up less as its percentage correct improves" do
    stat = stat("7x8", correct_count: 1, wrong_count: 3)
    before = weights["7x8"]

    stat.update!(correct_count: 9)
    assert_operator weights["7x8"], :<, before
  end
end
