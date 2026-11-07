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

ActiveRecord::Schema[8.1].define(version: 2026_11_07_100000) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.integer "record_id", null: false
    t.integer "blob_id", null: false
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
    t.integer "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "attempts", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "mode", default: "solo", null: false
    t.json "results", default: [], null: false
    t.json "powers", default: [], null: false
    t.integer "correct", default: 0, null: false
    t.integer "answered", default: 0, null: false
    t.integer "score", default: 0, null: false
    t.integer "best_streak", default: 0, null: false
    t.integer "top_tier", default: 1, null: false
    t.boolean "new_best", default: false, null: false
    t.string "client_id"
    t.datetime "played_at", null: false
    t.date "played_on", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["played_on", "score"], name: "index_attempts_on_played_on_and_score"
    t.index ["user_id", "client_id"], name: "index_attempts_on_user_id_and_client_id", unique: true
    t.index ["user_id", "played_on", "score"], name: "index_attempts_on_user_id_and_played_on_and_score"
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

  create_table "league_memberships", force: :cascade do |t|
    t.integer "league_id", null: false
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["league_id", "user_id"], name: "index_league_memberships_on_league_id_and_user_id", unique: true
    t.index ["league_id"], name: "index_league_memberships_on_league_id"
    t.index ["user_id"], name: "index_league_memberships_on_user_id"
  end

  create_table "leagues", force: :cascade do |t|
    t.integer "owner_id", null: false
    t.string "name", null: false
    t.string "join_code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["join_code"], name: "index_leagues_on_join_code", unique: true
    t.index ["owner_id"], name: "index_leagues_on_owner_id"
  end

  create_table "live_game_drops", force: :cascade do |t|
    t.integer "live_game_id", null: false
    t.string "power_up", null: false
    t.integer "claimed_by_id"
    t.datetime "claimed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["claimed_by_id"], name: "index_live_game_drops_on_claimed_by_id"
    t.index ["live_game_id"], name: "index_live_game_drops_on_live_game_id"
  end

  create_table "live_game_players", force: :cascade do |t|
    t.integer "live_game_id", null: false
    t.integer "user_id", null: false
    t.integer "attempt_id"
    t.integer "live_score", default: 0, null: false
    t.integer "answered", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["attempt_id"], name: "index_live_game_players_on_attempt_id"
    t.index ["live_game_id", "user_id"], name: "index_live_game_players_on_live_game_id_and_user_id", unique: true
    t.index ["live_game_id"], name: "index_live_game_players_on_live_game_id"
    t.index ["user_id"], name: "index_live_game_players_on_user_id"
  end

  create_table "live_games", force: :cascade do |t|
    t.integer "host_id"
    t.string "code", null: false
    t.boolean "matched", default: false, null: false
    t.datetime "starts_at"
    t.integer "rematch_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_live_games_on_code", unique: true
    t.index ["host_id"], name: "index_live_games_on_host_id"
    t.index ["rematch_id"], name: "index_live_games_on_rematch_id"
  end

  create_table "match_requests", force: :cascade do |t|
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_match_requests_on_user_id", unique: true
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
    t.string "name"
    t.string "theme", default: "system", null: false
    t.boolean "sounds", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "attempts", "users"
  add_foreign_key "badges", "attempts", on_delete: :nullify
  add_foreign_key "badges", "users"
  add_foreign_key "league_memberships", "leagues"
  add_foreign_key "league_memberships", "users"
  add_foreign_key "leagues", "users", column: "owner_id"
  add_foreign_key "live_game_drops", "live_games"
  add_foreign_key "live_game_drops", "users", column: "claimed_by_id"
  add_foreign_key "live_game_players", "attempts", on_delete: :nullify
  add_foreign_key "live_game_players", "live_games"
  add_foreign_key "live_game_players", "users"
  add_foreign_key "live_games", "live_games", column: "rematch_id", on_delete: :nullify
  add_foreign_key "live_games", "users", column: "host_id"
  add_foreign_key "match_requests", "users"
  add_foreign_key "sessions", "users"
end
