class AddDeadlineColumnToTasks < ActiveRecord::Migration[5.1]
  def up
    add_column :tasks, :deadline, :datetime
  end
  def down
    remove_column :tasks, :deadline
  end
end
