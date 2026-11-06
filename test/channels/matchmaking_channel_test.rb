require "test_helper"

class MatchmakingChannelTest < ActionCable::Channel::TestCase
  test "the second player looking is matched with the first" do
    MatchRequest.enter(users(:ada))
    stub_connection current_user: users(:bob)
    subscribe
    assert subscription.confirmed?
    game = LiveGame.last
    assert game.matched?
    assert_equal [ users(:ada), users(:bob) ], game.users.to_a
  end

  test "leaving takes them out" do
    stub_connection current_user: users(:ada)
    subscribe
    assert MatchRequest.exists?(user: users(:ada))
    unsubscribe
    assert_not MatchRequest.exists?(user: users(:ada))
  end

  test "it needs someone signed in" do
    stub_connection current_user: nil
    subscribe
    assert subscription.rejected?
  end
end
