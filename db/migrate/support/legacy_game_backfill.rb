# A snapshot of the October 2026 reward rules. Historical migrations must not load application models:
# their callbacks and scopes can depend on columns which have not been migrated yet.
class LegacyGameBackfill
  TOPICS = {
    "times_tables" => { scores: [ 5, 10, 25, 50, 75, 100 ], lightning: 1_000, quick: 2_000 },
    "equations" => { scores: [ 5, 10, 20, 30, 50 ], lightning: 3_000, quick: 6_000 },
    "functions" => { scores: [ 5, 10, 20, 30, 50 ], lightning: 3_000, quick: 6_000 },
    "simultaneous" => { scores: [ 5, 10, 15, 20, 30 ], lightning: 5_000, quick: 10_000 }
  }.freeze

  def initialize(connection)
    @connection = connection
  end

  def badges(perfect_answers:)
    @connection.select_values("SELECT DISTINCT user_id FROM attempts").each do |user_id|
      games = @connection.select_all("SELECT * FROM attempts WHERE user_id = #{quote(user_id)} ORDER BY played_at, id").to_a
      earned = @connection.select_values("SELECT kind FROM badges WHERE user_id = #{quote(user_id)}").to_set
      games.each do |game|
        kinds(game, games, perfect_answers).each do |kind|
          next if earned.include?(kind)

          now = quote(Time.current)
          @connection.execute(<<~SQL)
            INSERT INTO badges (user_id, attempt_id, kind, earned_at, created_at, updated_at)
            VALUES (#{quote(user_id)}, #{quote(game["id"])}, #{quote(kind)}, #{quote(game["played_at"] || game["created_at"])}, #{now}, #{now})
          SQL
          earned.add(kind)
        end
      end
    end
  end

  def stars
    @connection.select_all("SELECT * FROM attempts").each do |game|
      topic = TOPICS[game["topic"]]
      next unless topic

      stars = results(game).sum do |answer|
        next 0 unless answer["correct"]

        if answer["ms"] < topic[:lightning] then 30
        elsif answer["ms"] < topic[:quick] then 20
        else 10
        end
      end
      stars += 50 if perfect?(game, 10)
      stars += 50 if flag?(game["new_high_score"])
      stars += 100 if flag?(game["levelled_up"])
      @connection.execute("UPDATE attempts SET stars = #{stars} WHERE id = #{quote(game["id"])}")
    end
  end

  private
    def kinds(game, games, perfect_answers)
      topic = TOPICS[game["topic"]]
      return [] unless topic

      earlier = games.select { |other| other["played_at"] <= game["played_at"] }
      kinds = []
      kinds << "first_game" if game["answered"] >= 5
      kinds << "all_topics" if game["answered"] >= 5 && (TOPICS.keys - earlier.select { |other| other["answered"] >= 5 }.map { |other| other["topic"] }).empty?
      topic[:scores].each { |score| kinds << "score_#{score}_#{game['topic']}" if game["score"] >= score }
      [ 3, 7, 14, 30, 100 ].each { |days| kinds << "streak_#{days}" if game["streak"] >= days }
      reached = game["level"] + (flag?(game["levelled_up"]) ? 1 : 0)
      (2..5).each { |level| kinds << "level_#{level}_#{game['topic']}" if reached >= level }
      kinds << "perfect" if perfect?(game, perfect_answers)
      if game["answered"] >= 20
        ms = results(game).sum { |answer| answer["ms"] }
        kinds << "speedy" if ms < 2_000 * game["answered"]
        kinds << "lightning" if ms < 1_000 * game["answered"]
      end
      kinds << "comeback" if comeback?(game, earlier)
      kinds
    end

    def comeback?(game, earlier)
      previous = earlier.reject { |other| other["id"] == game["id"] }
      same_level = previous.any? { |other| other["topic"] == game["topic"] && other["level"] == game["level"] && practice?(other) }
      last_played = previous.map { |other| other["played_at"] }.max
      flag?(game["new_high_score"]) && same_level && last_played && Time.parse(last_played) <= Time.parse(game["played_at"]) - 7.days
    end

    def practice?(game)
      game.key?("mode") ? game["mode"] == "practice" : !flag?(game["daily_challenge"])
    end

    def perfect?(game, minimum)
      game["answered"] >= minimum && game["score"] == game["answered"]
    end

    def results(game)
      JSON.parse(game["results"])
    end

    def flag?(value)
      value == true || value == 1
    end

    def quote(value)
      @connection.quote(value)
    end
end
