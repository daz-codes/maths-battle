require "test_helper"

class Group::Challenge::ListingTest < ActiveSupport::TestCase
  setup do
    @owner = users(:ada)
    @player = users(:bob)
    @group = @owner.owned_groups.create!(name: "Class 4B")
    @group.join(@player)
  end

  test "lists load only displayed rounds and first scores, in a fixed number of queries" do
    challenges = 5.times.map do
      challenge = @group.challenges.create!(topic: "times_tables", level: 2, daily: true)
      5.times do |day|
        challenge.rounds.create!(day: @group.today - day - 1, questions: challenge.round.questions)
      end
      3.times do
        Attempt.record!(user: @owner, topic: "times_tables", level: 2, mode: "group", round: challenge.round,
          results: [ { a: 2, b: 3, given: 6, ms: 1000 } ])
      end
      challenge
    end

    single, single_queries, = read_listing([ challenges.first.id ])
    all, all_queries, rounds_loaded = read_listing(challenges.map(&:id))

    assert_equal single_queries.size, all_queries.size, "queries must not grow with the number of challenges"
    assert_equal 5, rounds_loaded, "historical rounds must not be instantiated"
    assert all_queries.none? { |sql| sql.match?(/SELECT.*(?:"questions"|"results"|"group_rounds"\.\*|"attempts"\.\*)/i) }
    assert_equal 1, single.cards.size
    assert_equal 5, all.cards.size
    assert_equal challenges.map(&:id).sort, all.waiting_challenges.map(&:id).sort
  end

  private
    def read_listing(ids)
      queries = []
      rounds_loaded = 0
      sql = ->(_name, _start, _finish, _id, payload) { queries << payload[:sql] if payload[:sql].start_with?("SELECT") }
      records = ->(_name, _start, _finish, _id, payload) { rounds_loaded += payload[:record_count] if payload[:class_name] == "Group::Round" }
      listing = nil
      ActiveSupport::Notifications.subscribed(sql, "sql.active_record") do
        ActiveSupport::Notifications.subscribed(records, "instantiation.active_record") do
          listing = Group::Challenge::Listing.new(Group::Challenge.where(id: ids).includes(group: :owner), user: @player)
        end
      end
      [ listing, queries, rounds_loaded ]
    end
end
