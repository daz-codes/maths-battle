# Groups: players who joined with a code, and the challenges their owner sets them. Each challenge's round is one
# set of questions everyone plays, and a game played for it is linked to the round
class CreateGroups < ActiveRecord::Migration[8.1]
  def up
    create_table :groups do |t|
      t.string :name, null: false
      t.references :owner, null: false, foreign_key: { to_table: :users }
      t.string :join_code, null: false
      t.timestamps
    end
    add_index :groups, :join_code, unique: true

    create_table :group_memberships do |t|
      t.references :group, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end
    add_index :group_memberships, %i[ group_id user_id ], unique: true

    create_table :group_challenges do |t|
      t.references :group, null: false, foreign_key: true
      t.string :topic, null: false
      t.integer :level, null: false
      t.boolean :owner_plays, null: false, default: true
      t.datetime :ends_at
      t.datetime :closed_at
      t.timestamps
    end

    create_table :group_rounds do |t|
      t.references :challenge, null: false, foreign_key: { to_table: :group_challenges }
      t.json :questions, null: false
      t.timestamps
    end

    # Without a foreign key: in SQLite adding one rebuilds the attempts table, and rebuilding it would clear every
    # badge's link to the game that earned it. Group::Round nullifies its games' link when it goes
    add_reference :attempts, :round
  end

  def down
    remove_index :attempts, :round_id
    remove_attempt_column :round_id
    drop_table :group_rounds
    drop_table :group_challenges
    drop_table :group_memberships
    drop_table :groups
  end

  private
    # SQLite rebuilds attempts when dropping a column, and its ON DELETE SET NULL foreign key would detach badges
    # during the rebuild, so their links are put back (as in ReplaceDailyChallengeWithMode)
    def remove_attempt_column(column)
      badges = select_rows("SELECT id, attempt_id FROM badges WHERE attempt_id IS NOT NULL")
      remove_column :attempts, column
      badges.each do |id, attempt_id|
        execute "UPDATE badges SET attempt_id = #{connection.quote(attempt_id)} WHERE id = #{connection.quote(id)}"
      end
    end
end
