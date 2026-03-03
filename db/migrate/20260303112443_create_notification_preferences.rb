class CreateNotificationPreferences < ActiveRecord::Migration[8.1]
  def change
    create_table :notification_preferences do |t|
      t.references :user, null: false, foreign_key: true
      t.string :notification_type, null: false
      t.boolean :enabled, default: true, null: false
      t.jsonb :config, default: {}

      t.timestamps
    end

    add_index :notification_preferences, [:user_id, :notification_type], unique: true
  end
end
