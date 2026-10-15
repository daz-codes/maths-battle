require "test_helper"

class TimesTables::QuestionGeneratorTest < ActiveSupport::TestCase
  setup { @user = users(:ada) }

  def generate(count: 150, seed: 1)
    TimesTables::QuestionGenerator.new(@user, count: count, random: Random.new(seed)).questions
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

  test "facts the user gets wrong come up more often" do
    @user.fact_stats.create!(topic: "times_tables", fact: "7x8", correct_count: 1, wrong_count: 5, last_wrong_at: 1.day.ago)

    weights = TimesTables::QuestionGenerator.new(@user).weights
    assert_operator weights[[ 7, 8 ]], :>, weights[[ 6, 8 ]] * 3

    questions = generate(count: 5000)
    assert_operator questions.count { |q| key(q) == "7x8" }, :>, questions.count { |q| key(q) == "6x8" } * 3
  end

  test "facts the user always gets right keep their normal weight" do
    @user.fact_stats.create!(topic: "times_tables", fact: "2x3", correct_count: 20, wrong_count: 0)

    weights = TimesTables::QuestionGenerator.new(@user).weights
    assert_equal weights[[ 2, 4 ]], weights[[ 2, 3 ]]
  end
end
