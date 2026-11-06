require "test_helper"

class MatchRequestTest < ActiveSupport::TestCase
  test "two looking are matched into a battle" do
    assert_nil MatchRequest.enter(users(:ada))
    game = MatchRequest.enter(users(:bob))
    assert_equal [ users(:ada), users(:bob) ], game.users.to_a
    assert_equal 0, MatchRequest.count
  end

  test "leaving stops looking" do
    MatchRequest.enter(users(:ada))
    MatchRequest.leave(users(:ada))
    assert_nil MatchRequest.enter(users(:bob))
  end

  test "someone whose page went quiet long ago isn't matched" do
    MatchRequest.enter(users(:ada))
    travel MatchRequest::STALE_AFTER + 1.second
    assert_nil MatchRequest.enter(users(:bob))
  end

  test "at most four go in a battle, those waiting longest" do
    users = [ users(:ada), users(:bob), users(:cy) ]
    MatchRequest.create!(user: users[0])
    MatchRequest.create!(user: users[1])
    MatchRequest.create!(user: users[2])
    extras = Array.new(2) { User.create!(name: "Extra") }
    MatchRequest.create!(user: extras[0])
    game = MatchRequest.enter(extras[1])
    assert_equal users + [ extras[0] ], game.users.to_a
    assert_equal [ extras[1] ], MatchRequest.all.map(&:user)
  end
end
