require "test_helper"

class User::ReviewableTest < ActiveSupport::TestCase
  setup { @user = users(:ada) }

  def play(*results)
    Attempt.record!(user: @user, results: results)
  end

  def right(a, b, ms: 1_000) = { a: a, b: b, given: a * b, ms: ms }
  def wrong(a, b) = { a: a, b: b, given: a * b + 1, ms: 1_000 }

  test "recent mistakes first, then the slowest right answers, each asked again exactly" do
    play(right(2, 3), right(2, 4), right(4, 4, ms: 9_000), wrong(3, 5), right(5, 5, ms: 6_000))
    play(wrong(3, 5), wrong(2, 5))

    review = @user.review_questions(TimesTables)
    assert_equal [ "3 × 5", "2 × 5", "4 × 4", "5 × 5" ], review.map { _1[:text] }
    assert_equal [ "15", "10", "16", "25" ], review.map { _1[:answer] }
  end

  test "nothing to review without mistakes or slow answers" do
    play(right(2, 3), right(2, 4), right(3, 4))
    assert_empty @user.review_questions(TimesTables)
    assert_empty @user.review_questions(Equations)
  end

  test "only the last 10 games" do
    play(wrong(4, 5))
    User::Reviewable::REVIEW_GAMES.times { play(right(2, 3)) }

    assert_empty User.find(@user.id).review_questions(TimesTables)
  end

  test "at most 20 questions" do
    play(*(2..12).flat_map { |a| [ wrong(a, 2), wrong(a, 3) ] }.first(22))
    assert_equal User::Reviewable::MAX_REVIEW_QUESTIONS, @user.review_questions(TimesTables).size
  end

  test "questions the topic no longer asks are left out" do
    unlock(@user, SimultaneousEquations, 1)
    old_pair = { "type" => "multiply both", "a" => 3, "b" => 4, "c" => 13, "d" => 2, "e" => 1, "f" => 7, "v" => "y", "given" => "9", "correct" => false, "ms" => 1000 }
    @user.attempts.create!(topic: "simultaneous", results: [ old_pair ])

    assert_empty User.find(@user.id).review_questions(SimultaneousEquations)
  end

  test "a review game goes round its questions, never the same one twice in a row" do
    play(wrong(3, 5), wrong(2, 5), wrong(4, 5))
    questions = @user.review_sets(topic: TimesTables, count: 1).first[:questions]

    assert_equal User::Practisable::QUESTION_COUNT, questions.size
    assert_equal [ "10", "15", "20" ], questions.map { _1[:answer] }.uniq.sort
    assert questions.each_cons(2).none? { |one, other| one[:text] == other[:text] }
  end
end
