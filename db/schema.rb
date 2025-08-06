# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_08_06_154731) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "email_verification_tokens", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "token", limit: 255, null: false
    t.datetime "expires_at", precision: nil, null: false
    t.datetime "verified_at", precision: nil
    t.datetime "invalidated_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_email_verification_tokens_on_expires_at"
    t.index ["token"], name: "index_email_verification_tokens_on_token", unique: true
    t.index ["user_id"], name: "index_email_verification_tokens_on_user_id"
  end

  create_table "password_reset_tokens", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "token", limit: 255, null: false
    t.datetime "expires_at", precision: nil, null: false
    t.datetime "used_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_password_reset_tokens_on_expires_at"
    t.index ["token"], name: "index_password_reset_tokens_on_token", unique: true
    t.index ["user_id"], name: "index_password_reset_tokens_on_user_id"
  end

  create_table "user_sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "session_token", limit: 255, null: false
    t.inet "ip_address"
    t.text "user_agent"
    t.datetime "expires_at", precision: nil, null: false
    t.datetime "last_accessed_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_user_sessions_on_expires_at"
    t.index ["session_token"], name: "index_user_sessions_on_session_token", unique: true
    t.index ["user_id"], name: "index_user_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "uid", limit: 36, null: false
    t.string "email", limit: 255, null: false
    t.string "password_digest", null: false
    t.string "first_name", limit: 100
    t.string "last_name", limit: 100
    t.string "phone", limit: 20
    t.date "date_of_birth"
    t.string "avatar_url", limit: 500
    t.text "bio"
    t.datetime "email_verified_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_users_on_created_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["uid"], name: "index_users_on_uid", unique: true
  end

  add_foreign_key "email_verification_tokens", "users", on_delete: :cascade
  add_foreign_key "password_reset_tokens", "users", on_delete: :cascade
  add_foreign_key "user_sessions", "users", on_delete: :cascade
end
