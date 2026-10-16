require "test_helper"

class User::BadgeableTest < ActiveSupport::TestCase
  setup { @user = users(:ada) }

  test "catching up gives existing players the badges their games earned, from the games that earned them" do
    travel_to(10.days.ago) { Attempt.record!(user: @user, results: answers(*right_answers(5))) }
    best = Attempt.record!(user: @user, results: answers(*right_answers(25), ms: 500))
    earned_as_played = @user.badges.pluck(:kind, :attempt_id).sort

    @user.badges.delete_all
    @user.catch_up_badges!

    assert_equal earned_as_played, @user.badges.pluck(:kind, :attempt_id).sort
    assert_includes @user.badges.pluck(:kind), "comeback"
    assert_equal best, @user.badges.find_by(kind: "score_25_times_tables").attempt
  end

  test "catching up again changes nothing" do
    Attempt.record!(user: @user, results: answers(*right_answers(5)))

    assert_no_difference -> { Badge.count } do
      @user.catch_up_badges!
    end
  end

  test "badges go when the player does" do
    guest = User.create_guest!
    Attempt.record!(user: guest, results: answers(*right_answers(5)))

    assert_difference -> { Badge.count }, -guest.badges.count do
      guest.destroy
    end
  end
end
