class CreateJobApplications < ActiveRecord::Migration[8.1]
  def change
    create_table :job_applications do |t|
      t.references :user, null: false, foreign_key: true
      t.references :job, null: false, foreign_key: true
      t.string :status, null: false, default: "matched"
      t.float :score
      t.text :notes
      t.datetime :applied_at
      t.datetime :notified_at

      t.timestamps
    end

    add_index :job_applications, [ :user_id, :job_id ], unique: true
    add_index :job_applications, [ :user_id, :status ]
  end
end
