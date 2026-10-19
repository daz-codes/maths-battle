ENV["RAILS_ENV"] = "test"
require_relative "../../config/environment"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ARGV.fetch(0))
context = ActiveRecord::MigrationContext.new(Rails.root.join("db/migrate").to_s)
context.migrate(20261016180000)
connection = ActiveRecord::Base.connection

def insert_row(connection, table, attributes)
  columns = attributes.keys.map { |key| connection.quote_column_name(key) }.join(", ")
  values = attributes.values.map { |value| connection.quote(value) }.join(", ")
  connection.insert("INSERT INTO #{table} (#{columns}) VALUES (#{values})")
end

first_day = Time.utc(2026, 10, 1, 12)
second_day = first_day + 8.days
users = [ "legacy", "ten_answers" ].map do |username|
  insert_row(connection, "users", username: username, created_at: first_day, updated_at: first_day)
end
games = [ [ users[0], 20, first_day, true ], [ users[0], 25, second_day, false ], [ users[1], 10, first_day, false ] ].map do |user_id, score, time, levelled_up|
  results = Array.new(score) { { a: "2", b: "3", given: "6", correct: true, ms: 500 } }
  insert_row(connection, "attempts", user_id: user_id, score: score, answered: score, results: results.to_json,
    new_high_score: true, levelled_up: levelled_up, streak: 7, share_token: "legacy-#{user_id}-#{score}",
    played_at: time, played_on: time.to_date, created_at: time, updated_at: time)
end

context.migrate
links = connection.select_rows("SELECT id, attempt_id FROM badges ORDER BY id")
context.rollback
raise "Rollback detached badge games" unless links == connection.select_rows("SELECT id, attempt_id FROM badges ORDER BY id")
context.migrate
raise "Reapplying the migration detached badge games" unless links == connection.select_rows("SELECT id, attempt_id FROM badges ORDER BY id")
puts({ stars: connection.select_values("SELECT stars FROM attempts ORDER BY id"),
  modes: connection.select_values("SELECT mode FROM attempts ORDER BY id"),
  badges: connection.select_all("SELECT user_id, attempt_id, kind FROM badges ORDER BY id").to_a,
  users: users, games: games }.to_json)
