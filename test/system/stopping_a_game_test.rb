require "application_system_test_case"

class StoppingAGameTest < ApplicationSystemTestCase
  setup do
    sign_in users(:ada)
    click_on "Play level 1"
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

  test "the clock's hand goes round once in the minute, and stops while paused" do
    page.execute_script(<<~JS)
      const test = window.Stimulus.getControllerForElementAndIdentifier(document.querySelector("[data-controller=test]"), "test")
      test.endsAt = performance.now() + 45_000
    JS
    page.document.synchronize { raise Capybara::ExpectationNotMet unless hand_angle > 45 }
    assert_in_delta 90, hand_angle, 10, "a quarter of the minute gone is a quarter of the way round"

    find(".test__stop").click
    assert_selector ".test--paused"
    paused_at = hand_angle
    sleep 1
    assert_equal paused_at, hand_angle
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

  private
    def hand_angle
      find(".clock__hand", visible: :all)[:transform][/rotate\(([\d.]+)/, 1].to_f
    end
end
