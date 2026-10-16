require "test_helper"

class User::AbandonableTest < ActiveSupport::TestCase
  def guest_made(ago)
    travel_to(ago.ago) { User.create_guest! }
  end

  def guest_last_played(ago)
    travel_to(ago.ago) { User.create_guest!.tap { |guest| Attempt.record!(user: guest, results: answers(*right_answers(5))) } }
  end

  test "guests who never played go after a month" do
    gone, kept = guest_made(31.days), guest_made(29.days)

    User.destroy_abandoned_guests
    assert_not User.exists?(gone.id)
    assert User.exists?(kept.id)
  end

  test "guests who played are kept for a year after their last game" do
    gone, kept = guest_last_played(13.months), guest_last_played(11.months)

    User.destroy_abandoned_guests
    assert_not User.exists?(gone.id)
    assert User.exists?(kept.id)
  end

  test "a guest who comes back to play is kept, however old the account" do
    guest = guest_last_played(2.years)
    Attempt.record!(user: guest, results: answers(*right_answers(5)))

    User.destroy_abandoned_guests
    assert User.exists?(guest.id)
  end

  test "everything of theirs goes with them" do
    guest = travel_to(2.years.ago) do
      User.create_guest!.tap do |guest|
        guest.sessions.create!
        guest.update!(avatar_upload: Rack::Test::UploadedFile.new(file_fixture("photo.jpg"), "image/jpeg"))
        Attempt.record!(user: guest, results: answers(*right_answers(5)))
      end
    end

    assert_difference -> { Attempt.count } => -1, -> { FactStat.where(user: guest).count } => -FactStat.where(user: guest).count, -> { Session.count } => -1 do
      User.destroy_abandoned_guests
    end
    assert_not ActiveStorage::Attachment.exists?(record: guest)
  end

  test "registered players are never deleted, however long they've been away" do
    travel_to(3.years.ago) { users(:ada).touch }

    User.destroy_abandoned_guests
    assert User.exists?(users(:ada).id)
  end

  test "runs every night in production" do
    task = YAML.load(ERB.new(Rails.root.join("config/recurring.yml").read).result).dig("production", "destroy_abandoned_guests")

    assert_equal "User.destroy_abandoned_guests", task["command"]
    assert_equal "every day at 4am", task["schedule"]
  end
end
