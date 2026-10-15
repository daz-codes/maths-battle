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

ActiveRecord::Schema[8.2].define(version: 2026_10_15_160000) do
  create_table "attempts", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "topic", default: "times_tables", null: false
    t.integer "score", default: 0, null: false
    t.integer "answered", default: 0, null: false
    t.json "results", default: [], null: false
    t.boolean "new_high_score", default: false, null: false
    t.integer "streak", default: 0, null: false
    t.string "share_token", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["share_token"], name: "index_attempts_on_share_token", unique: true
    t.index ["user_id", "created_at"], name: "index_attempts_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_attempts_on_user_id"
  end

  create_table "fact_stats", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "topic", default: "times_tables", null: false
    t.string "fact", null: false
    t.integer "correct_count", default: 0, null: false
    t.integer "wrong_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "correct_ms", default: 0, null: false
    t.index ["user_id", "topic", "fact"], name: "index_fact_stats_on_user_id_and_topic_and_fact", unique: true
    t.index ["user_id"], name: "index_fact_stats_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "username"
    t.string "password_digest"
    t.integer "current_streak", default: 0, null: false
    t.integer "longest_streak", default: 0, null: false
    t.date "last_practised_on"
    t.integer "high_score", default: 0, null: false
    t.string "time_zone", default: "London", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.string "theme", default: "system", null: false
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "attempts", "users"
  add_foreign_key "fact_stats", "users"
  add_foreign_key "sessions", "users"
end
