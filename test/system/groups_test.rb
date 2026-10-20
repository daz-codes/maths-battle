require "application_system_test_case"

class GroupsTest < ApplicationSystemTestCase
  test "an owner starts a group and sets a challenge; a player joins with the code, plays it, and sees the leaderboard" do
    sign_in users(:ada)
    find(".site-footer__groups").click
    click_on "Start a group"
    fill_in "What's it called?", with: "Class 4B"
    click_on "Start the group"
    code = find(".group-code__code").text

    click_on "+ New challenge"
    select "✖️ Times tables", from: "Topic"
    select "Level 1: Tables 2–5", from: "Level"
    choose "1 day"
    uncheck "I'm playing too"
    click_on "Set the challenge"
    assert_selector "h1", text: "Times tables · Level 1"
    assert_text "No one's played yet"

    visit edit_profile_path
    click_on "Sign out"
    sign_in users(:bob)
    find(".site-footer__groups").click
    fill_in "Group code", with: code.downcase
    click_on "Join"
    click_on "Join the group"
    assert_text "You've joined Class 4B!"

    visit root_path
    find(".group-waiting").click
    assert_selector "h1", text: "Times tables · Level 1"
    click_on "Play", exact: true
    assert_selector ".question", text: "×", wait: 5
    page.execute_script(<<~JS)
      const test = window.Stimulus.getControllerForElementAndIdentifier(document.querySelector("[data-controller=test]"), "test")
      test.endsAt = performance.now() + 4000
      clearTimeout(test.endTimer)
    JS
    2.times do |i|
      find("body").send_keys(page.evaluate_script(%(window.Stimulus.getControllerForElementAndIdentifier(document.querySelector("[data-controller=test]"), "test").current.answer)))
      assert_selector ".test__score", text: (i + 1).to_s
    end

    assert_selector ".banner--group", text: "You're 1st of 1 in Class 4B", wait: 10
    click_on "See the leaderboard"
    assert_selector ".leaderboard__row--you", text: /bob\s*2/
  end

  test "the owner changes invitations and removes a player, then invites them back; leaving also permits a return" do
    group = users(:ada).owned_groups.create!(name: "Class 4B")
    group.join(users(:bob))
    sign_in users(:ada)
    visit group_path(group)
    original = find(".group-code__code").text
    accept_confirm { click_on "New invite code" }
    assert_text "Old codes and links no longer work"
    changed = find(".group-code__code").text
    assert_not_equal original, changed
    find(".group-members summary").click
    accept_confirm { click_on "Remove" }
    assert_text "Share the new code to invite them back"
    invitation = find(".group-code__code").text
    assert_not_equal changed, invitation

    visit edit_profile_path
    click_on "Sign out"
    sign_in users(:bob)
    visit join_group_path(changed)
    assert_text "There's no group with that code"
    visit join_group_path(invitation)
    click_on "Join the group"
    assert_text "You've joined Class 4B!"

    accept_confirm { click_on "Leave this group" }
    assert_text "You can join again with its current invite code"
    visit join_group_path(invitation)
    click_on "Join the group"
    assert_text "You've joined Class 4B!"
  end

  test "a guest plays today's percentages round and the final day and week remain after closing" do
    group = users(:ada).owned_groups.create!(name: "Class 4B")
    challenge = group.challenges.create!(topic: "percentages", level: 3, daily: true, owner_plays: false)
    visit join_group_path(group.join_code)
    fill_in "What should we call you?", with: "Zara"
    click_on "Join the group"
    find(".challenge-card").click
    click_on "Play today's"
    assert_selector ".question", text: "%", wait: 5
    page.execute_script(<<~JS)
      const test = window.Stimulus.getControllerForElementAndIdentifier(document.querySelector("[data-controller=test]"), "test")
      test.endsAt = performance.now() + 4000
      clearTimeout(test.endTimer)
    JS
    2.times do |i|
      find("body").send_keys(page.evaluate_script('window.Stimulus.getControllerForElementAndIdentifier(document.querySelector("[data-controller=test]"), "test").current.answer'))
      assert_selector ".test__score", text: (i + 1).to_s
    end
    assert_selector ".banner--group", text: "You're 1st of 1 today in Class 4B", wait: 10
    click_on "See the leaderboard"
    click_on "Week total"
    assert_selector ".leaderboard__row--you", text: /Zara\s*2\s*1 day/
    click_on "Best day"
    assert_selector ".leaderboard__row--you", text: /Zara\s*2\s*total 2/
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")

    challenge.close!
    travel 2.weeks do
      visit group_challenge_path(group, challenge)
      assert_selector ".board-switch a", text: "Final day"
      assert_selector ".leaderboard__row--you", text: /Zara\s*2/
      click_on "Final week", exact: true
      assert_selector ".leaderboard__row--you", text: /Zara\s*2\s*1 day/
      assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
      page.save_screenshot("/tmp/matheminute-group-fixed-final-board.png")
    end
  end
end
