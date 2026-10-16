class AddGuestsNamesAndThemesToUsers < ActiveRecord::Migration[8.1]
  def change
    # Guests have an account but no username or password until they sign up
    change_column_null :users, :username, true
    change_column_null :users, :password_digest, true
    add_column :users, :name, :string
    add_column :users, :theme, :string, null: false, default: "system"

    # Questions are now weighted by percentage correct, so when a fact was last wrong no longer matters
    remove_column :fact_stats, :last_wrong_at, :datetime
  end
end
