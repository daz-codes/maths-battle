# NULL days identify one-off rounds; the existing day index only enforces uniqueness for daily rounds
class HardenGroupRounds < ActiveRecord::Migration[8.1]
  def change
    add_index :group_rounds, :challenge_id, unique: true, where: "day IS NULL", name: "index_group_rounds_on_one_off_challenge"
    add_index :attempts, %i[ round_id user_id ]
  end
end
