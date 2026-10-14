class CreateJobs < ActiveRecord::Migration[8.1]
  def change
    create_table :jobs do |t|
      t.string :title
      t.string :company
      t.string :url
      t.text :description
      t.string :location
      t.boolean :remote
      t.integer :salary_min
      t.string :source
      t.string :external_id
      t.datetime :posted_at
      t.jsonb :embedding

      t.timestamps
    end
    add_index :jobs, :url, unique: true
  end
end
