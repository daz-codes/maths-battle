require "application_system_test_case"

class GhostRaceTest < ApplicationSystemTestCase
  test "taking up a challenge races the challenger's game: their score as it was, ahead then behind" do
    ada, bob = users(:ada), users(:bob)
    ada.update!(name: "Ada")
    ada.owned_groups.create!(name: "Class 4B").join(bob)
    # Ada got 2 right in the first second, lightning fast (60), then nothing more for the rest of the minute
    game = Attempt.record!(user: ada, level: 1, results: [ { a: 2, b: 3, given: 6, ms: 400 }, { a: 2, b: 4, given: 8, ms: 400 } ])
    head_to_head = HeadToHead.from_game(game, opponent: bob)

    sign_in bob
    visit play_path("times-tables", head_to_head: head_to_head.id)
    assert_selector ".test__best", text: "Beat 60"
    assert_selector ".test__ghost", text: "Ada 0"

    assert_selector ".question", text: "×", wait: 5
    assert_selector ".test__ghost.test__ghost--ahead", text: "Ada 60", wait: 3

    3.times do |answered|
      a, b = find(".question--current").text.split(" × ").map(&:to_i)
      find("body").send_keys((a * b).to_s)
      assert_selector "[data-test-target=right]", text: /#{answered + 1}/
    end
    assert_selector ".test__ghost.test__ghost--behind", text: "Ada 60"
    assert_selector ".test__best", text: "Winning!"
  end
end
