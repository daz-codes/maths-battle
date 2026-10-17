require "test_helper"

class Attempt::BadgeableTest < ActiveSupport::TestCase
  setup { @user = users(:ada) }

  def play(right: 5, wrong: 0, ms: 1000, **options)
    Attempt.record!(user: @user, results: answers(*right_answers(right), *Array.new(wrong) { [ 2, 3, 1 ] }, ms: ms), **options)
  end

  def earned
    @user.badges.pluck(:kind)
  end

  test "finishing a first game earns First minute, but walking away doesn't" do
    play(right: 4)
    assert_not_includes earned, "first_game"

    game = play(right: 5)
    assert_equal [ "first_game" ], game.badges.map(&:kind) - [ "score_5_times_tables" ]
  end

  test "score badges are for the topic played" do
    play(right: 25, ms: 500)
    assert_includes earned, "score_25_times_tables"
    assert_includes earned, "score_10_times_tables"
    assert_not_includes earned, "score_50_times_tables"
    assert_not_includes earned, "score_10_equations"
  end

  test "each badge is earned once, by the first game to meet it" do
    first = play(right: 10)
    second = play(right: 10)

    assert_includes first.badges.map(&:kind), "score_10_times_tables"
    assert_empty second.badges
  end

  test "streak badges come with the streak" do
    (1..3).each { |day| travel_to(Time.zone.local(2026, 10, day, 12)) { play } }
    assert_includes earned, "streak_3"
    assert_not_includes earned, "streak_7"
  end

  test "levelling up earns that level's badge" do
    unlock(@user, TimesTables, 2)

    assert_includes earned, "level_2_times_tables"
    assert_equal true, @user.badges.find_by(kind: "level_2_times_tables").attempt.levelled_up
    assert_not_includes earned, "level_3_times_tables"
  end

  test "a perfect game needs every answer right, with at least 20 answered" do
    play(right: 19)
    play(right: 25, wrong: 1)
    assert_not_includes earned, "perfect"

    play(right: 20)
    assert_includes earned, "perfect"
  end

  test "speed badges go by the average time over a proper game" do
    play(right: 10, ms: 500)
    assert_not_includes earned, "lightning", "too few answers"

    play(right: 20, ms: 1500)
    assert_includes earned, "speedy"
    assert_not_includes earned, "lightning"

    play(right: 30, ms: 900)
    assert_includes earned, "lightning"
  end

  test "All-rounder is for playing every topic" do
    *others, last = Topic::ALL
    others.each { |topic| Attempt.record!(user: @user, topic: topic.key, results: [ EASY_QUESTIONS.fetch(topic) ] * 5) }
    assert_not_includes earned, "all_topics"

    Attempt.record!(user: @user, topic: last.key, results: [ EASY_QUESTIONS.fetch(last) ] * 5)
    assert_includes earned, "all_topics"
  end

  test "Comeback is a new best after a week or more away" do
    travel_to(10.days.ago) { play(right: 5) }
    play(right: 6)
    assert_includes earned, "comeback"
  end

  test "no Comeback after a short break, or for a first go at a level" do
    travel_to(3.days.ago) { play(right: 5) }
    play(right: 6)
    assert_not_includes earned, "comeback"

    @user.badges.delete_all
    travel_to(10.days.ago) { unlock(@user, TimesTables, 2) }
    Attempt.record!(user: @user, level: 2, results: answers(*right_answers(5)))
    assert_not_includes earned, "comeback", "nothing to beat at level 2 yet"
  end

  test "a game played offline earns its badges as of when it was played" do
    game = play(played_at: 2.days.ago.iso8601)
    assert_in_delta 2.days.ago, @user.badges.find_by(kind: "first_game").earned_at, 1.minute
    assert_equal game, @user.badges.find_by(kind: "first_game").attempt
  end
end
