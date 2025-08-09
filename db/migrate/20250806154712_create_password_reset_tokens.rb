class CreatePasswordResetTokens < ActiveRecord::Migration[8.0]
  def up
    create_table :password_reset_tokens do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade, to_table: :users }
      t.string :token, null: false, limit: 255
      t.timestamp :expires_at, null: false
      t.timestamp :used_at

      t.timestamps
    end

    add_index :password_reset_tokens, :token, unique: true
    add_index :password_reset_tokens, :expires_at
  end

  def down
    drop_table :password_reset_tokens
  end
end
