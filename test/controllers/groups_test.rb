require "test_helper"

class GroupsTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:ada)
    @group = @owner.owned_groups.create!(name: "Class 4B")
  end

  def set_challenge(topic: "times_tables", level: "2", duration: "1 week", owner_plays: "1")
    post group_challenges_path(@group), params: { group_challenge: { topic: topic, level: level, duration: duration, owner_plays: owner_plays } }
    @group.challenges.last
  end

  test "Compete is on the home page, not the footer; the page lists a player's groups, joining by code, and starting one" do
    sign_in_as @owner
    get groups_path

    assert_select ".site-footer a.site-footer__groups", count: 0, message: "Compete is on the home page instead"
    assert_select ".home-actions", count: 0
    assert_select "a.group-card[href=?]", group_path(@group), text: /Class 4B.*1 player · You run it/m
    assert_select "form[action=?][method=get] input[name=code]", join_group_path
    assert_select "a[href=?]", new_group_path, text: "Create a Group"
    assert_select "a[href=?] svg", new_group_path, 1, "with the group icon"
  end

  test "starting a group needs an account" do
    post lesson_completion_path("times-tables", 1), as: :json # a guest
    get new_group_path
    assert_redirected_to new_registration_path
  end

  test "the owner starts a group, gets a code to share, and sets a challenge that runs for a while" do
    sign_in_as @owner
    post groups_path, params: { group: { name: "The Smiths" } }
    group = @owner.owned_groups.last
    assert_redirected_to group
    follow_redirect!
    assert_select ".group-code__code", text: group.join_code
    assert_select "[data-share-text-value*=?]", join_group_url(group.join_code)

    @group = group
    get new_group_challenge_path(group)
    assert_select "select[name='group_challenge[topic]'] option[value=percentages]", text: "Percentages"
    assert_select "select[name='group_challenge[level]'] option[value='2']", text: "Level 2: Tables 2–12"
    assert_select "select[name='group_challenge[level]'] option[value=mixed]", text: "Mixed: every level"
    challenge = set_challenge(topic: "percentages", level: "3", duration: "3 days")
    assert_equal [ "percentages", 3 ], [ challenge.topic, challenge.level ]
    assert_in_delta 3.days.from_now, challenge.ends_at, 5
    assert_redirected_to group_challenge_path(group, challenge)

    assert_nil set_challenge(duration: "Until I close it").ends_at
  end

  test "a visitor joins from the link, saying their name for the leaderboard; a wrong code is turned away" do
    get join_group_path(@group.join_code.downcase)
    assert_select "h1", text: "Join Class 4B?"
    assert_select "input[name=name][required]"

    post group_joins_path, params: { code: @group.join_code, name: "Zara" }
    player = User.last
    assert player.guest?
    assert_equal "Zara", player.name
    assert @group.member?(player)
    assert_redirected_to group_path(@group)

    get join_group_path, params: { code: "NOPE22" }
    assert_redirected_to groups_path
  end

  test "joining with a typed code, and coming back to a group already joined" do
    sign_in_as users(:bob)
    get join_group_path, params: { code: @group.join_code }
    assert_select "input[name=name]", count: 0, message: "bob already has a name to show"
    post group_joins_path, params: { code: @group.join_code }
    assert @group.member?(users(:bob))

    get join_group_path(@group.join_code)
    assert_redirected_to group_path(@group)
  end

  test "only members see a group, and only the owner sets challenges or takes people out" do
    sign_in_as users(:bob)
    get group_path(@group)
    assert_response :not_found

    @group.join(users(:bob))
    get group_path(@group)
    assert_response :success
    assert_select "a[href=?]", new_group_challenge_path(@group), count: 0
    get new_group_challenge_path(@group)
    assert_response :not_found
    delete group_membership_path(@group, @group.memberships.find_by(user: @owner))
    assert_response :forbidden
  end

  test "a member can leave; the owner can take someone out, or delete the group" do
    @group.join(users(:bob))
    sign_in_as users(:bob)
    delete group_membership_path(@group, @group.memberships.find_by(user: users(:bob)))
    assert_not @group.member?(users(:bob))

    @group.join(users(:bob))
    sign_in_as @owner
    delete group_membership_path(@group, @group.memberships.find_by(user: users(:bob)))
    assert_not @group.member?(users(:bob))

    delete group_path(@group)
    assert_not Group.exists?(@group.id)
  end

  test "playing a challenge: its own questions, a ticket that saves it to the round, and where it puts you" do
    sign_in_as @owner
    challenge = set_challenge
    get play_path("times-tables", round: challenge.round.id)
    assert_select "[data-test-mode-value=group][data-test-level-value=2][data-test-round-value=?]", challenge.round.id.to_s
    set = JSON.parse(css_select("[data-controller=test]").first["data-test-question-sets-value"]).first
    assert_equal challenge.round.questions.map { _1["text"] }, set["questions"].map { _1["text"] }

    results = set["questions"].first(7).map { |question| question.slice("a", "b").merge("given" => question["answer"], "ms" => 1000) }
    post attempts_path, params: { attempt: { topic: "times_tables", level: 2, client_id: set["id"], ticket: set["ticket"], results: results } }, as: :json
    assert_response :created
    game = @owner.attempts.last
    assert_equal [ "group", challenge.round ], [ game.mode, game.round ]

    get attempt_path(game)
    assert_select "a.back-link[href=?]", group_path(@group), text: "← Class 4B"
    assert_select ".banner--group", text: "You're 1st of 1 in Class 4B"
    assert_select "a[href=?]", group_challenge_path(@group, challenge), text: "See the leaderboard"

    get group_challenge_path(@group, challenge)
    assert_select ".challenge__you", text: "You scored 200: 1st of 1"
    assert_select ".leaderboard__row--you .leaderboard__score", text: "200", message: "7 right, quick, the 5th to 7th doubled"
    assert_select "a.button", text: "Play again (just for practice)"
  end

  test "the home page says when a group challenge is waiting, and a closed one can't be played" do
    @group.join(users(:bob))
    sign_in_as @owner
    challenge = set_challenge

    sign_in_as users(:bob)
    get root_path
    assert_select "a.group-waiting[href=?]", group_challenge_path(@group, challenge), text: /Class 4B challenge.*Times tables · Level 2/m

    challenge.close!
    get root_path
    assert_select ".group-waiting", count: 0
    get play_path("times-tables", round: challenge.round.id)
    assert_redirected_to groups_path
  end

  test "the owner closes a challenge; the leaderboard stays" do
    sign_in_as @owner
    challenge = set_challenge
    post group_challenge_closing_path(@group, challenge)
    assert_not challenge.reload.open?
    follow_redirect!
    assert_select ".aside", text: /Ended/
  end

  test "a leaderboard shows other players by their letter, never their picture" do
    @group.join(users(:bob))
    users(:bob).avatar.attach(io: file_fixture("photo.jpg").open, filename: "photo.jpg")
    sign_in_as @owner
    get group_path(@group)
    assert_select ".group-members__player img.avatar", count: 0
    assert_select ".group-members__player .avatar--letter", 2
  end

  test "an every day challenge: set, played today, three leaderboards, and yesterday's round can't be played" do
    sign_in_as @owner
    post group_challenges_path(@group), params: { group_challenge: { topic: "times_tables", level: "2", daily: "1", duration: "Until I close it", owner_plays: "1" } }
    challenge = @group.challenges.last
    assert challenge.daily?
    follow_redirect!
    assert_select ".aside", text: /Every day · Until it.s closed/
    assert_select ".board-switch a", 3
    assert_select "a.button", text: "Play today's"

    get play_path("times-tables", round: challenge.round.id)
    set = JSON.parse(css_select("[data-controller=test]").first["data-test-question-sets-value"]).first
    results = set["questions"].first(6).map { |question| question.slice("a", "b").merge("given" => question["answer"], "ms" => 1000) }
    post attempts_path, params: { attempt: { topic: "times_tables", level: 2, client_id: set["id"], ticket: set["ticket"], results: results } }, as: :json
    get response.parsed_body["url"]
    assert_select ".banner--group", text: "You're 1st of 1 today in Class 4B"

    get group_challenge_path(@group, challenge, board: "total")
    assert_select ".board-switch a[aria-current=true]", text: "Week total"
    assert_select ".leaderboard__row--you .leaderboard__score", text: /160\s+1 day/
    get group_challenge_path(@group, challenge, board: "best")
    assert_select ".leaderboard__row--you .leaderboard__score", text: /160\s+total 160/

    yesterday = challenge.round
    travel 1.day do
      get play_path("times-tables", round: yesterday.id)
      assert_redirected_to groups_path
      get group_challenge_path(@group, challenge)
      assert_select "a.button", text: "Play today's"
    end
  end

  test "a one-off challenge has just the one leaderboard" do
    sign_in_as @owner
    get group_challenge_path(@group, set_challenge)
    assert_select ".board-switch", count: 0
  end

  test "removal revokes the old invitation, and the owner can invite that player back" do
    bob = users(:bob)
    @group.join(bob)
    code = @group.join_code
    sign_in_as @owner
    delete group_membership_path(@group, @group.memberships.find_by!(user: bob))
    assert_not @group.member?(bob)
    assert_not_equal code, @group.reload.join_code
    assert @group.member?(@owner)
    follow_redirect!
    assert_select ".group-code__code", text: @group.join_code
    assert_select ".flash", text: /Share the new code to invite them back/

    sign_in_as bob
    get group_path(@group)
    assert_response :not_found
    get join_group_path(code)
    assert_redirected_to groups_path
    post group_joins_path, params: { code: code }
    assert_not @group.member?(bob)

    post group_joins_path, params: { code: @group.join_code }
    assert_redirected_to group_path(@group)
    assert @group.member?(bob)
  end

  test "someone who leaves can return with the same code; leaving doesn't replace anyone else's invitations" do
    bob = users(:bob)
    @group.join(bob)
    code = @group.join_code
    sign_in_as bob
    delete group_membership_path(@group, @group.memberships.find_by!(user: bob))
    assert_equal code, @group.reload.join_code
    post group_joins_path, params: { code: code }
    assert @group.member?(bob)
  end

  test "only the owner can replace the invite code, and existing members stay joined" do
    @group.join(users(:bob))
    code = @group.join_code
    sign_in_as users(:bob)
    post group_invite_code_path(@group)
    assert_response :not_found
    assert_equal code, @group.reload.join_code

    sign_in_as @owner
    post group_invite_code_path(@group)
    assert_redirected_to group_path(@group)
    assert_not_equal code, @group.reload.join_code
    assert @group.member?(users(:bob))
    follow_redirect!
    assert_select "form[action=?]", group_invite_code_path(@group)
  end

  test "lookups and joins share a working rate limit, including the typed and linked code routes" do
    store = GroupJoinsController.cache_store
    original = store.method(:increment)
    cache = ActiveSupport::Cache::MemoryStore.new
    store.define_singleton_method(:increment) { |*args, **options| cache.increment(*args, **options) }
    begin
      (GroupJoinsController::REQUESTS_PER_MINUTE / 2).times do
        get join_group_path, params: { code: "NOPE22" }
        post group_joins_path, params: { code: "NOPE22" }
      end
      get join_group_path(@group.join_code)
      assert_redirected_to groups_path
      assert_equal "Too many tries. Wait a minute, then try again.", flash[:alert]
      assert_select "h1", text: "Join Class 4B?", count: 0

      assert_no_difference "User.count" do
        post group_joins_path, params: { code: @group.join_code, name: "New player" }
        assert_equal "Too many tries. Wait a minute, then try again.", flash[:alert]
      end
    ensure
      store.define_singleton_method(:increment, original)
    end
  end

  test "signed replay uploads cannot replace a first score by changing played_at" do
    sign_in_as @owner
    challenge = set_challenge
    first = upload_group_game(challenge, score: 2, played_at: Time.current)
    replay = upload_group_game(challenge, score: 10, played_at: 2.minutes.ago)
    assert_equal first, challenge.entry_for(@owner).attempt
    get attempt_path(replay)
    assert_select ".banner--group", text: /Just for practice: your first saved score/
  end

  test "a closed daily challenge keeps its final boards on later days and weeks" do
    sign_in_as @owner
    challenge = @group.challenges.create!(topic: "times_tables", level: 2, daily: true)
    upload_group_game(challenge, score: 6)
    challenge.close!
    travel 2.weeks do
      assert_no_difference "challenge.rounds.count" do
        get group_challenge_path(@group, challenge)
        assert_select ".leaderboard__row--you .leaderboard__score", text: "160"
        assert_select ".board-switch a", text: "Final day"
        assert_select "a.button", text: /Play/, count: 0
        get group_challenge_path(@group, challenge, board: "total")
        assert_select ".leaderboard__row--you .leaderboard__score", text: /160\s+1 day/
        get group_challenge_path(@group, challenge, board: "best")
        assert_select ".leaderboard__row--you .leaderboard__score", text: /160\s+total 160/
        get group_path(@group)
        assert_select ".challenge-card__you", text: /Final day: You scored 160/
      end
    end
  end

  test "late signed uploads save the game without adding a score to the finished board" do
    sign_in_as @owner
    challenge = set_challenge
    get play_path("times-tables", round: challenge.round.id)
    set = JSON.parse(css_select("[data-controller=test]").first["data-test-question-sets-value"]).first
    challenge.close!
    travel 1.minute do
      late = upload_group_game(challenge, score: 6, played_at: 2.minutes.ago, set: set)
      assert_empty challenge.leaderboard
      get attempt_path(late)
      assert_select ".banner--group", text: /Saved to your history after the round ended/
    end
  end

  private
    def upload_group_game(challenge, score:, played_at: Time.current, set: nil)
      unless set
        get play_path("times-tables", round: challenge.round.id)
        set = JSON.parse(css_select("[data-controller=test]").first["data-test-question-sets-value"]).first
      end
      results = set["questions"].first(score).map { |question| question.slice("a", "b").merge("given" => question["answer"], "ms" => 1000) }
      post attempts_path, params: { attempt: { topic: "times_tables", level: 2, client_id: set["id"], ticket: set["ticket"], results: results, played_at: played_at.iso8601 } }, as: :json
      assert_response :created
      @owner.attempts.find_by!(client_id: set["id"])
    end

  test "a mixed challenge: every level of the topic, played at the top one" do
    sign_in_as @owner
    challenge = set_challenge(topic: "functions", level: "mixed")
    assert [ challenge.mixed?, challenge.level ] == [ true, 5 ]
    assert_equal "Functions · Mixed", challenge.title
    assert_operator challenge.round.questions.map { _1["type"] }.uniq.size, :>, Functions::INVERSE.size
    get group_challenge_path(@group, challenge)
    assert_select ".aside", text: /Every level/
  end

  test "a challenge says which group it's in, and goes back to it; a group goes back to the list" do
    sign_in_as @owner
    challenge = set_challenge
    get group_challenge_path(@group, challenge)
    assert_select "a.back-link[href=?]", group_path(@group), text: "← Class 4B"
    get group_path(@group)
    assert_select "a.back-link[href=?]", groups_path, text: "← Compete"
  end
end
