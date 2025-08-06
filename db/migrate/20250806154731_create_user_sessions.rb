class CreateUserSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :user_sessions do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade, to_table: :users }
      t.string :session_token, null: false, limit: 255
      t.inet :ip_address
      t.text :user_agent
      t.timestamp :expires_at, null: false
      t.timestamp :last_accessed_at, default: -> { 'CURRENT_TIMESTAMP' }

      t.timestamps
    end

    add_index :user_sessions, :session_token, unique: true
    add_index :user_sessions, :expires_at
  end
end
