# Daily reminders: a time on the player, and a push subscription for each device that should get them
class AddReminders < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :reminder_minute, :integer
    add_column :users, :reminded_on, :date

    create_table :push_subscriptions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :endpoint, null: false
      t.string :p256dh_key, null: false
      t.string :auth_key, null: false
      t.timestamps
    end
    add_index :push_subscriptions, :endpoint, unique: true
  end
end
