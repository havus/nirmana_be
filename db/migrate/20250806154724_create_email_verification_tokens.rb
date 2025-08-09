class CreateEmailVerificationTokens < ActiveRecord::Migration[8.0]
  def up
    create_table :email_verification_tokens do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade, to_table: :users }
      t.string :token, null: false, limit: 255
      t.timestamp :expires_at, null: false
      t.timestamp :verified_at
      t.timestamp :invalidated_at

      t.timestamps
    end

    add_index :email_verification_tokens, :token, unique: true
    add_index :email_verification_tokens, :expires_at
  end

  def down
    drop_table :email_verification_tokens
  end
end
