class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :uid, null: false, limit: 36
      t.string :email, null: false, limit: 255
      t.string :password_digest, null: false
      t.string :first_name, limit: 100
      t.string :last_name, limit: 100
      t.string :phone, limit: 20
      t.date :date_of_birth
      t.string :avatar_url, limit: 500
      t.text :bio
      t.timestamp :email_verified_at
      t.integer :status, default: 0, null: false

      t.timestamps
    end

    add_index :users, :uid, unique: true
    add_index :users, :email, unique: true
    add_index :users, :created_at
    add_index :users, :status
  end
end
