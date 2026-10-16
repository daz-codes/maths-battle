require "test_helper"

class Attempt::ReviewableTest < ActiveSupport::TestCase
  setup { @user = users(:ada) }

  def attempt_with(*triples)
    Attempt.record!(user: @user, results: answers(*triples))
  end

  test "names the weakest tables" do
    feedback = attempt_with([ 7, 8, 54 ], [ 8, 8, 63 ], [ 7, 7, 49 ], [ 6, 6, 36 ], [ 9, 9, 81 ])

    assert_equal [ 7, 8 ], feedback.weak_groups
    assert_equal "Practise your 7× and 8× tables", feedback.feedback_message
  end

  test "picks at most three tables" do
    feedback = attempt_with([ 2, 2, 5 ], [ 3, 3, 10 ], [ 4, 4, 17 ], [ 5, 5, 26 ], [ 6, 6, 37 ])
    assert_equal 3, feedback.weak_groups.size
  end

  test "lists each missed fact once with its answer" do
    feedback = attempt_with([ 7, 8, 54 ], [ 7, 8, 55 ], [ 6, 7, 42 ])
    assert_equal [ "7 × 8 = 56" ], feedback.missed_facts
  end

  test "lists right answers that were much slower than usual" do
    results = right_answers(10).map { |a, b, given| { a: a, b: b, given: given, ms: 1500 } }
    results << { a: 7, b: 8, given: 56, ms: 5000 } << { a: 6, b: 9, given: 54, ms: 2000 } << { a: 4, b: 4, given: 15, ms: 6000 }
    feedback = Attempt.record!(user: @user, results: results)

    assert_equal [ "7 × 8 = 56" ], feedback.slow_facts, "6 × 9 was only a little slow, and 4 × 4 was wrong, not slow"
    assert_equal [ "4 × 4 = 16" ], feedback.missed_facts
  end

  test "includes the last two weeks of history" do
    travel_to 3.days.ago do
      Attempt.record!(user: @user, results: answers(*Array.new(10) { [ 9, 4, 35 ] }))
    end
    travel_to 30.days.ago do
      Attempt.record!(user: @user, results: answers(*Array.new(10) { [ 11, 4, 43 ] }))
    end

    feedback = attempt_with([ 9, 9, 81 ], [ 9, 3, 27 ], [ 5, 5, 25 ])
    assert_includes feedback.weak_groups, 9
    assert_not_includes feedback.weak_groups, 11
  end

  test "says well done when everything was right" do
    feedback = attempt_with([ 2, 3, 6 ], [ 4, 5, 20 ])
    assert_empty feedback.missed_facts
    assert_equal "Every answer right. Brilliant, ada!", feedback.feedback_message
  end

  test "uses the player's name" do
    @user.update!(name: "Ada")
    assert_equal "Every answer right. Brilliant, Ada!", attempt_with([ 2, 3, 6 ]).feedback_message
  end
end
