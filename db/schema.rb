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

ActiveRecord::Schema[8.1].define(version: 2026_10_20_180000) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

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
    t.datetime "played_at"
    t.date "played_on"
    t.string "client_id"
    t.integer "level", default: 1, null: false
    t.boolean "levelled_up", default: false, null: false
    t.integer "best_score", default: 0, null: false
    t.integer "stars", default: 0, null: false
    t.boolean "earned_streak_freeze", default: false, null: false
    t.string "mode", default: "practice", null: false
    t.integer "round_id"
    t.index ["round_id", "user_id"], name: "index_attempts_on_round_id_and_user_id"
    t.index ["round_id"], name: "index_attempts_on_round_id"
    t.index ["share_token"], name: "index_attempts_on_share_token", unique: true
    t.index ["user_id", "client_id"], name: "index_attempts_on_user_id_and_client_id", unique: true
    t.index ["user_id", "created_at"], name: "index_attempts_on_user_id_and_created_at"
    t.index ["user_id", "played_on"], name: "index_attempts_on_user_id_and_played_on"
    t.index ["user_id", "topic", "mode", "played_on"], name: "index_attempts_on_user_id_and_topic_and_mode_and_played_on"
    t.index ["user_id"], name: "index_attempts_on_user_id"
  end

  create_table "badges", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "attempt_id"
    t.string "kind", null: false
    t.datetime "earned_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["attempt_id"], name: "index_badges_on_attempt_id"
    t.index ["user_id", "kind"], name: "index_badges_on_user_id_and_kind", unique: true
    t.index ["user_id"], name: "index_badges_on_user_id"
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
    t.integer "level", default: 1, null: false
    t.index ["user_id", "topic", "level", "fact"], name: "index_fact_stats_on_user_id_and_topic_and_level_and_fact", unique: true
    t.index ["user_id"], name: "index_fact_stats_on_user_id"
  end

  create_table "frozen_days", force: :cascade do |t|
    t.integer "user_id", null: false
    t.date "day", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "day"], name: "index_frozen_days_on_user_id_and_day", unique: true
    t.index ["user_id"], name: "index_frozen_days_on_user_id"
  end

  create_table "group_challenges", force: :cascade do |t|
    t.integer "group_id", null: false
    t.string "topic", null: false
    t.integer "level", null: false
    t.boolean "owner_plays", default: true, null: false
    t.datetime "ends_at"
    t.datetime "closed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "daily", default: false, null: false
    t.index ["group_id"], name: "index_group_challenges_on_group_id"
  end

  create_table "group_memberships", force: :cascade do |t|
    t.integer "group_id", null: false
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "nudged_on"
    t.index ["group_id", "user_id"], name: "index_group_memberships_on_group_id_and_user_id", unique: true
    t.index ["group_id"], name: "index_group_memberships_on_group_id"
    t.index ["user_id"], name: "index_group_memberships_on_user_id"
  end

  create_table "group_rounds", force: :cascade do |t|
    t.integer "challenge_id", null: false
    t.json "questions", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "day"
    t.index ["challenge_id", "day"], name: "index_group_rounds_on_challenge_id_and_day", unique: true
    t.index ["challenge_id"], name: "index_group_rounds_on_challenge_id"
    t.index ["challenge_id"], name: "index_group_rounds_on_one_off_challenge", unique: true, where: "day IS NULL"
  end

  create_table "groups", force: :cascade do |t|
    t.string "name", null: false
    t.integer "owner_id", null: false
    t.string "join_code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["join_code"], name: "index_groups_on_join_code", unique: true
    t.index ["owner_id"], name: "index_groups_on_owner_id"
  end

  create_table "lesson_completions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "topic", null: false
    t.integer "level", null: false
    t.date "completed_on", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "topic", "level", "completed_on"], name: "idx_on_user_id_topic_level_completed_on_544e031b58", unique: true
    t.index ["user_id"], name: "index_lesson_completions_on_user_id"
  end

  create_table "push_subscriptions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "endpoint", null: false
    t.string "p256dh_key", null: false
    t.string "auth_key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["endpoint"], name: "index_push_subscriptions_on_endpoint", unique: true
    t.index ["user_id"], name: "index_push_subscriptions_on_user_id"
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
    t.string "time_zone", default: "London", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.string "theme", default: "system", null: false
    t.integer "streak_freezes", default: 0, null: false
    t.integer "stars_spent", default: 0, null: false
    t.date "streak_kept_on"
    t.integer "reminder_minute"
    t.date "reminded_on"
    t.boolean "sounds", default: true, null: false
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "attempts", "users"
  add_foreign_key "badges", "attempts", on_delete: :nullify
  add_foreign_key "badges", "users"
  add_foreign_key "fact_stats", "users"
  add_foreign_key "frozen_days", "users"
  add_foreign_key "group_challenges", "groups"
  add_foreign_key "group_memberships", "groups"
  add_foreign_key "group_memberships", "users"
  add_foreign_key "group_rounds", "group_challenges", column: "challenge_id"
  add_foreign_key "groups", "users", column: "owner_id"
  add_foreign_key "lesson_completions", "users"
  add_foreign_key "push_subscriptions", "users"
  add_foreign_key "sessions", "users"
end
