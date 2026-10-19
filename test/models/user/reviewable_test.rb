require "test_helper"

class User::ReviewableTest < ActiveSupport::TestCase
  setup { @user = users(:ada) }

  def play(*results)
    Attempt.record!(user: @user, results: results)
  end

  def right(a, b, ms: 1_000) = { a: a, b: b, given: a * b, ms: ms }
  def wrong(a, b) = { a: a, b: b, given: a * b + 1, ms: 1_000 }

  test "recent mistakes, latest first, each asked again exactly; right answers, however slow, aren't reviewed" do
    play(right(2, 3), right(2, 4), right(4, 4, ms: 9_000), wrong(3, 5), right(5, 5, ms: 6_000))
    play(wrong(3, 5), wrong(2, 5))

    review = @user.review_questions(TimesTables)
    assert_equal [ "2 × 5", "3 × 5" ], review.map { _1[:text] }
    assert_equal [ "10", "15" ], review.map { _1[:answer] }
  end

  def review(*results) = Attempt.record!(user: @user, mode: "review", results: results)

  test "getting a question right, in a review or any game, takes it off the list" do
    play(wrong(3, 5), wrong(2, 5), wrong(4, 4), right(2, 3))
    review(wrong(3, 5), right(3, 5, ms: 9_000), right(2, 5), wrong(2, 5))
    play(right(4, 4))

    assert_equal [ "2 × 5" ], User.find(@user.id).review_questions(TimesTables).map { _1[:text] }, "3 × 5 and 4 × 4 were last answered right"
  end

  test "reviewing them all leaves nothing to review" do
    play(wrong(3, 5), wrong(2, 5), right(2, 3))
    review(*@user.review_questions(TimesTables).map { |question| { a: question[:a].to_i, b: question[:b].to_i, given: question[:answer].to_i, ms: 6_000 } })

    assert_empty User.find(@user.id).review_questions(TimesTables)
  end

  test "nothing to review without mistakes" do
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
