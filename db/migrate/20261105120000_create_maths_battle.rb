# Maths Battle starts with fresh data, so its whole schema is one migration
class CreateMathsBattle < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :username, index: { unique: true }
      t.string :password_digest
      t.string :name
      t.string :theme, null: false, default: "system"
      t.boolean :sounds, null: false, default: true
      t.timestamps
    end

    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :ip_address
      t.string :user_agent
      t.timestamps
    end

    # One minute's game, solo or in a battle. Its score is worked out from its answers (Attempt::Scorable), and
    # the day it counts towards in the leagues is played_on (League::Day)
    create_table :attempts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :mode, null: false, default: "solo"
      t.json :results, null: false, default: []
      t.json :powers, null: false, default: []
      t.integer :correct, null: false, default: 0
      t.integer :answered, null: false, default: 0
      t.integer :score, null: false, default: 0
      t.integer :best_streak, null: false, default: 0
      t.integer :top_tier, null: false, default: 1
      t.boolean :new_best, null: false, default: false
      t.string :client_id
      t.datetime :played_at, null: false
      t.date :played_on, null: false
      t.timestamps
      t.index %i[ user_id client_id ], unique: true
      t.index %i[ user_id played_on score ]
      t.index %i[ played_on score ]
    end

    create_table :leagues do |t|
      t.references :owner, null: false, foreign_key: { to_table: :users }
      t.string :name, null: false
      t.string :join_code, null: false, index: { unique: true }
      t.timestamps
    end

    create_table :league_memberships do |t|
      t.references :league, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.timestamps
      t.index %i[ league_id user_id ], unique: true
    end

    # A battle: a host's, with a code to join its lobby, or one made by matchmaking (no host), starting at once
    create_table :live_games do |t|
      t.references :host, foreign_key: { to_table: :users }
      t.string :code, null: false, index: { unique: true }
      t.boolean :matched, null: false, default: false
      t.datetime :starts_at
      t.references :rematch, foreign_key: { to_table: :live_games, on_delete: :nullify }
      t.timestamps
    end

    create_table :live_game_players do |t|
      t.references :live_game, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :attempt, foreign_key: { on_delete: :nullify }
      t.integer :live_score, null: false, default: 0
      t.integer :answered, null: false, default: 0
      t.timestamps
      t.index %i[ live_game_id user_id ], unique: true
    end

    # A power-up dropped into a battle when any player reaches another 10 answers. The first to tap it claims it,
    # and it hits everyone else (LiveGame::Droppable)
    create_table :live_game_drops do |t|
      t.references :live_game, null: false, foreign_key: true
      t.string :power_up, null: false
      t.references :claimed_by, foreign_key: { to_table: :users }
      t.datetime :claimed_at
      t.timestamps
    end

    # Someone on the Find a match page, while it's open (MatchmakingChannel)
    create_table :match_requests do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.timestamps
    end

    create_table :active_storage_blobs do |t|
      t.string :key, null: false
      t.string :filename, null: false
      t.string :content_type
      t.text :metadata
      t.string :service_name, null: false
      t.bigint :byte_size, null: false
      t.string :checksum
      t.datetime :created_at, null: false
      t.index [ :key ], unique: true
    end

    create_table :active_storage_attachments do |t|
      t.string :name, null: false
      t.references :record, null: false, polymorphic: true, index: false
      t.references :blob, null: false
      t.datetime :created_at, null: false
      t.index [ :record_type, :record_id, :name, :blob_id ], name: :index_active_storage_attachments_uniqueness, unique: true
      t.foreign_key :active_storage_blobs, column: :blob_id
    end

    create_table :active_storage_variant_records do |t|
      t.belongs_to :blob, null: false, index: false
      t.string :variation_digest, null: false
      t.index [ :blob_id, :variation_digest ], name: :index_active_storage_variant_records_uniqueness, unique: true
      t.foreign_key :active_storage_blobs, column: :blob_id
    end
  end
end
