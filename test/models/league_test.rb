require "test_helper"

class LeagueTest < ActiveSupport::TestCase
  test "the world league is everyone's best today, highest first" do
    play(users(:ada), rights: [ true ] * 3)
    play(users(:ada), rights: [ true ] * 5)
    play(users(:bob), rights: [ true ] * 4)
    entries = League.world.entries
    assert_equal [ users(:ada), users(:bob) ], entries.map(&:user)
    assert_equal [ 150, 100 ], entries.map(&:score)
    assert_equal [ 1, 2 ], entries.map(&:rank)
    assert_equal 2, League.world.size
  end

  test "ties share a place" do
    play(users(:ada), rights: [ true ] * 3)
    play(users(:bob), rights: [ true ] * 3)
    assert_equal [ 1, 1 ], League.world.entries.map(&:rank)
    assert_equal 1, League.world.entry_for(users(:bob)).rank
  end

  test "it starts again every day" do
    play(users(:ada), rights: [ true ] * 3)
    travel 1.day do
      assert_empty League.world.entries
      assert_nil League.world.entry_for(users(:ada))
      assert_equal users(:ada), League.world(League.today - 1).leader.user
    end
  end

  test "a guest with no name isn't in the world league" do
    play(User.create_guest!, rights: [ true ] * 5)
    assert_empty League.world.entries
  end

  test "a league's table is just its members" do
    league = League.create!(owner: users(:ada), name: "Smiths")
    league.join(users(:bob))
    play(users(:bob), rights: [ true ] * 2)
    play(users(:cy), rights: [ true ] * 5)
    assert_equal [ users(:bob) ], league.standings.entries.map(&:user)
    assert_equal 1, league.standings.entry_for(users(:bob)).rank
    assert_nil league.standings.entry_for(users(:ada))
  end

  test "the day goes by London time" do
    travel_to Time.utc(2026, 7, 1, 23, 30) do
      assert_equal Date.new(2026, 7, 2), League.today
    end
  end
end
