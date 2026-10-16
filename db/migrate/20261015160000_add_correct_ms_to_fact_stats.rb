class AddCorrectMsToFactStats < ActiveRecord::Migration[8.1]
  def change
    # Total time spent on right answers, so we know each fact's average answer time
    add_column :fact_stats, :correct_ms, :integer, null: false, default: 0
  end
end
