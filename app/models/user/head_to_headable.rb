# A player's head to heads (HeadToHead): who they can challenge, the ones waiting for them, and their record against
# each rival. There's no finding players by name: rivals are people they share a group with, or have played before
module User::HeadToHeadable
  extend ActiveSupport::Concern

  # Wins, losses and draws against one rival
  Record = Data.define(:won, :lost, :drew) do
    def self.empty = new(won: 0, lost: 0, drew: 0)
    def played = won + lost + drew
  end

  included do
    has_many :sent_head_to_heads, class_name: "HeadToHead", foreign_key: :challenger_id, dependent: :destroy, inverse_of: :challenger
    has_many :received_head_to_heads, class_name: "HeadToHead", foreign_key: :opponent_id, dependent: :destroy, inverse_of: :opponent
  end

  def head_to_heads
    HeadToHead.involving(self)
  end

  def rivals
    return User.none unless persisted?

    group_mates = Group::Membership.where(group_id: group_memberships.select(:group_id)).select(:user_id)
    User.where(id: group_mates)
      .or(User.where(id: sent_head_to_heads.select(:opponent_id)))
      .or(User.where(id: received_head_to_heads.select(:challenger_id)))
      .where.not(id: id)
  end

  def rival?(user)
    rivals.exists?(user.id)
  end

  # Sent to them and still to play, the soonest to run out first
  def head_to_heads_to_play
    return HeadToHead.none unless persisted?

    received_head_to_heads.waiting.includes(:challenger, :challenger_attempt).order(:expires_at)
  end

  def head_to_head_record(rival)
    head_to_head_records.fetch(rival.id, Record.empty)
  end

  # By rival's id, counted in one query
  def head_to_head_records
    @head_to_head_records ||= head_to_heads.decided.group(:challenger_id, :opponent_id, :winner_id).count
      .each_with_object(Hash.new { |records, rival_id| records[rival_id] = Record.empty }) do |((challenger_id, opponent_id, winner_id), count), records|
        rival_id = challenger_id == id ? opponent_id : challenger_id
        result = if winner_id.nil? then :drew elsif winner_id == id then :won else :lost end
        records[rival_id] = records[rival_id].with(result => records[rival_id].public_send(result) + count)
      end
  end
end
