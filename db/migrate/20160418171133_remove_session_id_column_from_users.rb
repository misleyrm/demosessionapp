class RemoveSessionIdColumnFromUsers < ActiveRecord::Migration[5.1]
  def up
    remove_column :users, :session_id, :integer
  end
  def down
    add_column :users, :session_id, :integer
  end
end
