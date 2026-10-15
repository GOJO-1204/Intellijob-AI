class AddUniqueIndexToJobApplications < ActiveRecord::Migration[7.1]
  def change
    add_index :job_applications, [ :user_id, :job_id ], unique: true, if_not_exists: true
  end
end
