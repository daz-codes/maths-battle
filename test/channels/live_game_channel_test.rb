require "test_helper"

class LiveGameChannelTest < ActionCable::Channel::TestCase
  setup do
    @ada, @bob = users(:ada), users(:bob)
    @game = LiveGame.make(host: @ada, topic: TimesTables, level: 1)
    @game.join(@bob)
  end

  test "only the game's players hear its scores, known by their pass, whoever the connection says" do
    stub_connection current_user: nil
    subscribe pass: @game.pass_for(User.create!(username: "carol", password: "a long password 123"))
    assert subscription.rejected?
    subscribe pass: "forged"
    assert subscription.rejected?

    subscribe pass: @game.pass_for(@bob)
    assert subscription.confirmed?
    assert_has_stream_for @game
  end

  test "a score and gems while the game's running go to everyone in it; not before, and never more than a game could have" do
    stub_connection current_user: nil
    subscribe pass: @game.pass_for(@bob)
    assert_no_broadcasts(LiveGameChannel.broadcasting_for(@game)) { perform :score, score: 3 }

    @game.start!
    travel 10.seconds do
      assert_broadcast_on(LiveGameChannel.broadcasting_for(@game), { type: "score", player_id: @bob.id, score: 3, gems: 70 }) { perform :score, score: 3, gems: 70 }
      assert_broadcast_on(LiveGameChannel.broadcasting_for(@game), { type: "score", player_id: @bob.id, score: Attempt::MAX_ANSWERS, gems: LiveGameChannel::MAX_GEMS }) do
        perform :score, score: 9999, gems: 99_999_999
      end
    end
  end

  test "in a Power game, gems said are kept to know who's ahead; a box goes only to its player; a power-up used goes to everyone" do
    @game.update!(mode: "power")
    stub_connection current_user: nil
    subscribe pass: @game.pass_for(@bob)
    @game.start!

    travel_to(@game.reload.starts_at + 16.seconds) do
      perform :score, score: 3, gems: 70
      assert_equal 70, @game.player_for(@bob).live_gems

      perform :open_box
      dealt = @game.player_for(@bob).power_up
      assert_includes LiveGame::ODDS[:leading].keys, dealt, "Bob's ahead of Ada"
      assert_equal({ "type" => "box", "power_up" => dealt }, transmissions.last)

      @game.player_for(@bob).update!(power_up: "freeze")
      assert_broadcast_on(LiveGameChannel.broadcasting_for(@game), { type: "power_up", power_up: "freeze", from: @bob.id, hit: [ @ada.id ], blocked: [] }) do
        perform :use_power_up
      end
      assert_no_broadcasts(LiveGameChannel.broadcasting_for(@game)) { perform :use_power_up }
    end
  end
end
