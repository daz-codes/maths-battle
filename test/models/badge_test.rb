require "test_helper"

class BadgeTest < ActiveSupport::TestCase
  def kinds(user)
    user.badges.pluck(:kind)
  end

  test "a first game earns its award, and streaks, right answers and scores theirs" do
    play(users(:ada), rights: [ true ] * 12)
    assert_includes kinds(users(:ada)), "first_game"
    assert_includes kinds(users(:ada)), "streak_10"
    assert_includes kinds(users(:ada)), "right_10"
    assert_includes kinds(users(:ada)), "score_500"
    assert_includes kinds(users(:ada)), "perfect"
    assert_not_includes kinds(users(:ada)), "streak_20"
  end

  test "each is earned once, by the first game" do
    first = play(users(:ada), rights: [ true ] * 3)
    play(users(:ada), rights: [ true ] * 3)
    assert_equal 1, users(:ada).badges.where(kind: "first_game").count
    assert_equal first, users(:ada).badges.find_by(kind: "first_game").attempt
  end

  test "claiming a power-up earns Powered up and that power-up's own" do
    play(users(:ada), rights: [ true ] * 12, powers: [ "shield" ] * PowerUp::MOST, claims: [ { drop: 1, at: 10 } ])
    assert_includes kinds(users(:ada)), "first_power_up"
    assert_includes kinds(users(:ada)), "power_shield"
  end

  test "a battle: finishing one, the power-ups tapped in it, and winning once everyone's in" do
    game = LiveGame.host!(users(:ada))
    game.join(users(:bob))
    game.start!
    travel LiveGame::START_LEAD + 1.second
    drop = game.drops.create!(power_up: "freeze")
    game.claim(drop.id, game.player_for(users(:ada)))

    play(users(:ada), rights: [ true ] * 5, live_game: game)
    assert_includes kinds(users(:ada)), "first_battle"
    assert_includes kinds(users(:ada)), "power_freeze"
    assert_not_includes kinds(users(:ada)), "first_win", "not until everyone's game is in"

    play(users(:bob), rights: [ true ] * 2, live_game: game)
    assert_includes kinds(users(:ada)), "first_win"
    assert_not_includes kinds(users(:bob)), "first_win"
  end

  test "joining a league is Team player" do
    League.create!(owner: users(:ada), name: "Smiths").join(users(:bob))
    assert_includes kinds(users(:ada)), "team_player"
    assert_includes kinds(users(:bob)), "team_player"
  end

  test "the records: the longest streak, most right and highest score, each from one game" do
    play(users(:ada), rights: [ true ] * 6 + [ false ])
    play(users(:ada), rights: [ true, false ] * 5)
    assert_equal 6, users(:ada).longest_streak
    assert_equal 6, users(:ada).most_correct
    assert_equal 210, users(:ada).best_score
  end
end
