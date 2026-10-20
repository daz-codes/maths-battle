# One set of questions for a challenge, the same for everyone who plays it: a one-off challenge's only one, or
# one day of an every day challenge's
class Group::Round < ApplicationRecord
  belongs_to :challenge
  has_many :attempts, dependent: :nullify

  # The database's unique indexes cover both dated and one-off rounds. A validation here races with
  # find_or_create_by!: it can raise RecordInvalid before that method can recover the competing insert

  # Each player's first server-saved score, across these rounds. Read only the fields a leaderboard needs,
  # and keep people who've left out in the query. Practice replays never load their answer JSON here
  def self.first_goes(rounds)
    first_ids = Attempt.where(round_id: rounds.map(&:id)).group(:round_id, :user_id).select("MIN(id)")
    Attempt.where(id: first_ids).joins(round: :challenge)
      .joins("INNER JOIN groups ON groups.id = group_challenges.group_id")
      .joins("INNER JOIN group_memberships ON group_memberships.group_id = groups.id AND group_memberships.user_id = attempts.user_id")
      .where("group_challenges.owner_plays = ? OR attempts.user_id != groups.owner_id", true)
      .select(:id, :user_id, :round_id, :score, :answered, :created_at).includes(:user)
  end

  # Late offline games are still saved for the player, but cannot change a finished leaderboard
  def counts?(attempt)
    cutoff = [ challenge.ended_at, (day.in_time_zone(challenge.group.owner.time_zone).end_of_day if day) ].compact.min
    cutoff.nil? || attempt.created_at <= cutoff
  end

  # Unweighted (a new player's questions), so no one's history makes the set easier or harder for them
  def self.questions_for(challenge)
    User.new.questions(topic: challenge.topic_module, level: challenge.level)
  end

  # Only today's round can be played: yesterday's questions are known by now
  def current?
    challenge.round == self
  end
end
