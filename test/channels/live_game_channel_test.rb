require "test_helper"

class LiveGameChannelTest < ActionCable::Channel::TestCase
  setup do
    @game = LiveGame.host!(users(:ada))
    @game.join(users(:bob))
    @game.start!
    travel LiveGame::START_LEAD + 1.second
  end

  test "a player's tenth answer drops a power-up for everyone, and the first to claim it gets it" do
    subscribe pass: @game.pass_for(users(:ada))
    assert subscription.confirmed?
    assert_broadcasts(@game, 2) { perform :score, score: 100, correct: 10, answered: 10 }
    drop = @game.drops.last
    assert_broadcast_on(@game, { type: "claimed", id: drop.id, power_up: drop.power_up, by: users(:ada).id }) { perform :claim, id: drop.id }
    assert_no_broadcasts(@game) { perform :claim, id: drop.id }
  end

  test "a stranger can't listen in" do
    subscribe pass: "nonsense"
    assert subscription.rejected?
  end
end
