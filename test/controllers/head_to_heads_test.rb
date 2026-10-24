require "test_helper"

class HeadToHeadsTest < ActionDispatch::IntegrationTest
  setup do
    @ada, @bob = users(:ada), users(:bob)
    @ada.update!(name: "Ada")
    @bob.update!(name: "Bob")
    @group = @ada.owned_groups.create!(name: "Class 4B")
    @group.join(@bob)
  end

  # Plays the game the page gave out, getting every one of the first `right` questions right
  def play_from_page(user, right:)
    set = JSON.parse(css_select("[data-controller=test]").first["data-test-question-sets-value"]).first
    results = set["questions"].first(right).map { |question| question.slice("a", "b").merge("given" => question["answer"], "ms" => 1000) }
    post attempts_path, params: { attempt: { topic: "times_tables", level: set_level, client_id: set["id"], ticket: set["ticket"], results: results } }, as: :json
    assert_response :created
    user.attempts.last
  end

  def set_level
    css_select("[data-controller=test]").first["data-test-level-value"]
  end

  def practice_game(right: 10)
    Attempt.record!(user: @ada, level: 1, results: Array.new(right) { { a: 2, b: 3, given: 6, ms: 1000 } })
  end

  test "after a game: challenge a friend to beat it, picking from the people in your groups" do
    sign_in_as @ada
    game = practice_game
    get attempt_path(game)
    assert_select "a.button--challenge[href=?]", new_head_to_head_path(attempt: game), text: "Challenge a friend to beat 340"

    get new_head_to_head_path(attempt: game)
    assert_select ".rival-row", count: 1
    assert_select ".rival-row__name", text: "Bob"
    assert_select ".rival-row__record", text: "No games yet"

    assert_difference "HeadToHead.count" do
      post head_to_heads_path, params: { opponent_id: @bob.id, attempt_id: game.id }
    end
    head_to_head = HeadToHead.last
    assert_equal [ @ada, @bob, game ], [ head_to_head.challenger, head_to_head.opponent, head_to_head.challenger_attempt ]
    assert_redirected_to head_to_head
    follow_redirect!
    assert_select ".flash, .notice, p", text: "Sent! Bob has 3 days to beat your 340."
    assert_select ".banner", text: /Waiting for Bob · 3 days left/
  end

  test "without a group there's no one to pick, but the game can still go as a link; only people you know can be picked" do
    @group.destroy!
    sign_in_as @ada
    game = practice_game
    get attempt_path(game)
    get new_head_to_head_path(attempt: game)
    assert_select ".rival-row", count: 0
    assert_select "form[action=?] button", head_to_heads_path, text: "Share a link"

    post head_to_heads_path, params: { opponent_id: @bob.id, attempt_id: game.id }
    assert_response :not_found
  end

  test "sent as a link: the first to open it and play is the opponent, a guest giving their name, and they're rivals after" do
    sign_in_as @ada
    game = practice_game(right: 9)
    assert_difference "HeadToHead.count" do
      2.times { post head_to_heads_path, params: { attempt_id: game.id } }
    end
    head_to_head = HeadToHead.last
    assert_nil head_to_head.opponent
    assert_redirected_to head_to_head
    follow_redirect!
    assert_select "h1", text: /You vs \?/
    assert_select "[data-controller=share][data-share-text-value=?]",
      "Ada scored 280 in a minute at Times tables · Level 1. Can you beat it? #{head_to_head_link_url(head_to_head.share_token)}"
    assert_select ".banner", text: /Sent as a link · 3 days left/
    sign_out

    get head_to_head_link_path(head_to_head.share_token)
    assert_select "h1", text: /Ada challenged you!/
    assert_select ".head-to-head-link__target", text: "Beat 280 in a minute"
    assert_select "input[name=name][required]"
    post head_to_head_link_path(head_to_head.share_token)
    assert_redirected_to head_to_head_link_path(head_to_head.share_token), "a name first"

    post head_to_head_link_path(head_to_head.share_token), params: { name: "Zara" }
    zara = User.find_by(name: "Zara")
    assert zara.guest?
    assert_equal zara, head_to_head.reload.opponent
    assert_redirected_to play_path("times-tables", head_to_head: head_to_head.id)
    follow_redirect!
    play_from_page(zara, right: 3)
    assert_equal @ada, head_to_head.reload.winner
    assert zara.rival?(@ada)

    sign_in_as @bob
    get head_to_head_link_path(head_to_head.share_token)
    assert_select ".aside", text: "Someone else has already taken up this challenge."
    get head_to_head_link_path("nope")
    assert_redirected_to root_path
  end

  test "the friend sees it on the home page, plays the same questions to beat the score, and both see who won" do
    head_to_head = HeadToHead.from_game(practice_game(right: 4), opponent: @bob)

    sign_in_as @bob
    get root_path
    assert_select "a.head-to-head-waiting[href=?]", head_to_head_path(head_to_head), text: /Ada challenged you!.*Times tables · Level 1 · Beat 80/m

    get head_to_head_path(head_to_head)
    assert_select "h1", text: /You vs Ada/
    assert_select "a.button[href=?]", play_path("times-tables", head_to_head: head_to_head.id), text: "Play · beat 80"

    get play_path("times-tables", head_to_head: head_to_head.id)
    assert_select "[data-test-mode-value=head_to_head][data-test-best-value='80'][data-test-passed-value='Winning!']"
    assert_select ".test__best", text: "Beat 80"
    ghost = JSON.parse(css_select("[data-controller=test]").first["data-test-ghost-value"])
    assert_equal({ "name" => "Ada", "steps" => [ [ 1000, 20 ], [ 2000, 40 ], [ 3000, 60 ], [ 4000, 80 ] ] }, ghost)
    assert_select ".test__ghost", text: "Ada 0"
    game = play_from_page(@bob, right: 6)
    assert_equal [ "head_to_head", game ], [ game.mode, head_to_head.reload.opponent_attempt ]
    assert_equal @bob, head_to_head.winner

    get attempt_path(game)
    assert_select ".banner--group", text: "You won 160–80"
    assert_select "a[href=?]", head_to_head_path(head_to_head), text: "See the head to head"

    get play_path("times-tables", head_to_head: head_to_head.id)
    assert_redirected_to groups_path, "one go each"
    get root_path
    assert_select "a.head-to-head-waiting", count: 0

    sign_in_as @ada
    get head_to_head_path(head_to_head)
    assert_select ".versus__score", text: "80"
    assert_select ".versus__player--winner .versus__score", text: "160"
    assert_select ".head-to-head__record", text: "Against Bob: Lost 1"
    assert_select "form[action=?] button", head_to_heads_path, text: "Rematch"
  end

  test "a rematch is new questions the challenger plays first, then it's sent" do
    sign_in_as @ada
    get groups_path
    assert_select "h1", text: "Compete"
    assert_select ".rival-row", count: 0, message: "challenges start from a game"

    post head_to_heads_path, params: { opponent_id: @bob.id, topic: "times_tables", level: 1 }
    head_to_head = HeadToHead.last
    assert_not head_to_head.sent?
    assert_redirected_to play_path("times-tables", head_to_head: head_to_head.id)
    get groups_path
    assert_select ".challenge-card", count: 0, message: "not shown until both have played"
    get play_path("times-tables", head_to_head: head_to_head.id)
    assert_select ".test__best", count: 0, message: "nothing to beat when playing first"
    assert_select ".test__ghost", count: 0
    game = play_from_page(@ada, right: 5)
    assert_equal game, head_to_head.reload.challenger_attempt

    get attempt_path(game)
    assert_select ".banner--group", text: "Sent! Bob has 3 days to beat your 120."
    get groups_path
    assert_select ".challenge-card", count: 0, message: "still waiting for Bob"

    sign_in_as @bob
    get play_path("times-tables", head_to_head: head_to_head.id)
    play_from_page(@bob, right: 2)
    sign_in_as @ada
    get groups_path
    assert_select ".challenge-card", text: /You vs Bob.*You won 120–40/m
  end

  test "only its two players see a head to head" do
    head_to_head = HeadToHead.from_game(practice_game, opponent: @bob)
    sign_in_as User.create!(username: "carol", password: "a long password 123")
    get head_to_head_path(head_to_head)
    assert_response :not_found
    get play_path("times-tables", head_to_head: head_to_head.id)
    assert_redirected_to groups_path
  end
end
