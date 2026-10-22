# A head to head can be sent as a link: its opponent is whoever opens it first, so there's none until then.
# Only head_to_heads is rebuilt by SQLite here, never attempts
class AddShareLinksToHeadToHeads < ActiveRecord::Migration[8.1]
  def change
    change_column_null :head_to_heads, :opponent_id, true
    add_column :head_to_heads, :share_token, :string
    add_index :head_to_heads, :share_token, unique: true
  end
end
