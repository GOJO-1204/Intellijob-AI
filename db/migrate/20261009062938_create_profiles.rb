class CreateProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :profiles do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.text :resume_text
      t.string :target_role
      t.string :target_skills, array: true, default: []
      t.string :location
      t.boolean :remote
      t.integer :salary_min
      t.string :experience_level
      t.string :alert_frequency, default: "daily"
      t.integer :ats_score
      t.jsonb :ats_feedback, default: {}
      t.jsonb :ai_suggestions, default: []
      t.jsonb :embedding

      t.timestamps
    end
  end
end