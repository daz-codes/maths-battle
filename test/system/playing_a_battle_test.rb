require "application_system_test_case"

class PlayingABattleTest < ApplicationSystemTestCase
  # The scores below are known only if no drop turns into the Bomb, which is up to chance for someone far behind
  setup do
    @bomb_chance = LiveGame::Droppable::BOMB_CHANCE
    LiveGame::Droppable.send(:remove_const, :BOMB_CHANCE)
    LiveGame::Droppable.const_set(:BOMB_CHANCE, 0)
  end

  teardown do
    LiveGame::Droppable.send(:remove_const, :BOMB_CHANCE)
    LiveGame::Droppable.const_set(:BOMB_CHANCE, @bomb_chance)
  end

  test "a hosted battle: joining with its code, starting together, a power-up of your own claimed hitting the other, and the podium" do
    sign_in users(:ada)
    within("main") { click_on "Multiplayer" }
    click_on "Host a battle"
    assert_selector "h1", text: "Battle"
    code = LiveGame.last.code

    using_session :zara do
      visit multiplayer_path
      fill_in "Battle code", with: code
      click_on "Join battle"
      fill_in "What should we call you?", with: "Zara"
      click_on "Join the game"
      assert_text "Waiting for Ada to start…"
    end

    assert_selector "#live-players", text: "Zara", wait: 5
    click_on "Start"
    assert_selector ".test__rival", text: "Zara 0"
    using_session(:zara) { assert_selector ".question--current", text: /[×÷+−]/, wait: 12 }
    assert_selector ".question--current", text: /[×÷+−]/, wait: 12

    # Zara's power-ups are her own: Ada doesn't see them. Ada's come with her own answers, and what she claims
    # reaches Zara
    using_session(:zara) { 10.times { answer_question } }
    assert_selector ".test__rival", text: "Zara 550", wait: 5
    3.times { answer_question }
    assert_selector ".test__spinner", wait: 5
    find(".test__spinner").click
    assert_selector ".test__spinner--landed", wait: 5
    using_session(:zara) { assert_selector ".test__power-news", text: "Ada", wait: 5 }
    shorten_the_game
    using_session(:zara) { shorten_the_game }

    assert_selector ".banner", text: "You came 2nd", wait: 15
    using_session(:zara) { assert_selector ".banner", text: "You came 1st", wait: 15 }
    assert_selector "#live-podium .leaderboard__row", text: /Zara.*550/m
  end

  test "finding a match: two players looking are put in a battle together" do
    sign_in users(:ada)
    visit match_path
    click_on "Start looking"
    assert_text "Looking for players…"

    using_session :zara do
      visit match_path
      fill_in "What should we call you?", with: "Zara"
      click_on "Start looking"
      assert_selector ".test__rival", text: "Ada 0", wait: 10
    end
    assert_selector ".test__rival", text: "Zara 0", wait: 10
    assert LiveGame.last.matched?
  end
end
