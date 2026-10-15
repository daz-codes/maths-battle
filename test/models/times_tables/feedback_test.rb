require "test_helper"

class TimesTables::FeedbackTest < ActiveSupport::TestCase
  setup { @user = users(:ada) }

  def feedback_for(*triples)
    TimesTables::Feedback.new(Attempt.record!(user: @user, results: answers(*triples)))
  end

  test "names the weakest tables" do
    feedback = feedback_for([ 7, 8, 54 ], [ 8, 8, 63 ], [ 7, 7, 49 ], [ 6, 6, 36 ], [ 9, 9, 81 ])

    assert_equal [ 7, 8 ], feedback.weak_tables
    assert_equal "Practise your 7× and 8× tables", feedback.message
  end

  test "picks at most three tables" do
    feedback = feedback_for([ 2, 2, 5 ], [ 3, 3, 10 ], [ 4, 4, 17 ], [ 5, 5, 26 ], [ 6, 6, 37 ])
    assert_equal 3, feedback.weak_tables.size
  end

  test "lists each missed fact once with its answer" do
    feedback = feedback_for([ 7, 8, 54 ], [ 7, 8, 55 ], [ 6, 7, 42 ])
    assert_equal [ "7 × 8 = 56" ], feedback.missed_facts
  end

  test "includes the last two weeks of history" do
    travel_to 3.days.ago do
      Attempt.record!(user: @user, results: answers(*Array.new(10) { [ 9, 4, 35 ] }))
    end
    travel_to 30.days.ago do
      Attempt.record!(user: @user, results: answers(*Array.new(10) { [ 11, 4, 43 ] }))
    end

    feedback = feedback_for([ 9, 9, 81 ], [ 9, 3, 27 ], [ 5, 5, 25 ])
    assert_includes feedback.weak_tables, 9
    assert_not_includes feedback.weak_tables, 11
  end

  test "says well done when everything was right" do
    feedback = feedback_for([ 2, 3, 6 ], [ 4, 5, 20 ])
    assert_empty feedback.missed_facts
    assert_equal "Every answer right. Brilliant, ada!", feedback.message
  end

  test "uses the player's name" do
    @user.update!(name: "Ada")
    assert_equal "Every answer right. Brilliant, Ada!", feedback_for([ 2, 3, 6 ]).message
  end
end
