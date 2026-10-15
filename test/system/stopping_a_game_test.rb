require "application_system_test_case"

class StoppingAGameTest < ApplicationSystemTestCase
  setup do
    sign_in users(:ada)
    click_on "Play"
    assert_selector ".question", text: "×", wait: 5
  end

  test "keep playing: the clock was paused and the game carries on" do
    find(".test__stop").click
    assert_selector "dialog[open]", text: "Stop this game?"
    assert_selector ".test--paused"
    seconds = find(".test__seconds").text

    sleep 1.5
    click_on "Keep playing"
    assert_no_selector "dialog[open]"
    assert_operator find(".test__seconds").text.to_i, :>=, seconds.to_i - 1, "no time lost while paused"

    a, b = find(".question").text.split(" × ").map(&:to_i)
    find("body").send_keys((a * b).to_s)
    assert_selector ".test__score", text: "1"
  end

  test "stop game: back home and nothing saved" do
    a, b = find(".question").text.split(" × ").map(&:to_i)
    find("body").send_keys((a * b).to_s)

    assert_no_difference -> { Attempt.count } do
      find(".test__stop").click
      click_on "Stop game"
      assert_selector ".streak"
    end
  end
end
