# What a challenge tells its players: that it's been set, and when someone has taken 1st place from them, which
# is at most once a day for each group, so it's a nudge rather than a nag (User::Notifiable)
module Group::Challenge::Announceable
  extend ActiveSupport::Concern

  included do
    after_create_commit :announce
  end

  # A first go that takes 1st place from someone (not a tie) tells them
  def played(attempt)
    board = leaderboard(attempt.round)
    winner = board.first
    return unless winner&.attempt == attempt

    beaten = board.second
    return unless beaten && beaten.rank > 1 && beaten.user != attempt.user

    membership = group.memberships.find_by(user: beaten.user)
    return if membership.nil? || membership.nudged_on == group.today

    membership.update!(nudged_on: group.today)
    beaten.user.notify_later(title: "😮 #{attempt.user.display_name} just took 1st place from you",
      body: "#{title} in #{group.name}#{" today" if daily?}. Your first score still counts. See the leaderboard!", url: link)
  end

  private
    def announce
      players.where.not(id: group.owner_id).find_each do |player|
        player.notify_later(title: "🏆 New challenge in #{group.name}",
          body: "#{title}#{" · new questions every day" if daily?}. Everyone plays the same questions!", url: link)
      end
    end

    def link
      Rails.application.routes.url_helpers.group_challenge_path(group, self)
    end
end
