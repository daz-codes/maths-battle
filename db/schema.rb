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

ActiveRecord::Schema[8.1].define(version: 2026_10_17_100001) do
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
    t.index ["share_token"], name: "index_attempts_on_share_token", unique: true
    t.index ["user_id", "client_id"], name: "index_attempts_on_user_id_and_client_id", unique: true
    t.index ["user_id", "created_at"], name: "index_attempts_on_user_id_and_created_at"
    t.index ["user_id", "played_on"], name: "index_attempts_on_user_id_and_played_on"
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
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "attempts", "users"
  add_foreign_key "badges", "attempts", on_delete: :nullify
  add_foreign_key "badges", "users"
  add_foreign_key "fact_stats", "users"
  add_foreign_key "sessions", "users"
end
