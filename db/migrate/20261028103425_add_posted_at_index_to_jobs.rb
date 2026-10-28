class AddPostedAtIndexToJobs < ActiveRecord::Migration[8.1]
  def change
    add_index :jobs, :posted_at
  end
end
