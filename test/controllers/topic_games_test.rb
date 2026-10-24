require "test_helper"

# Every topic must use the same signed game flow, including questions from earlier levels in mixed games.
class TopicGamesTest < ActionDispatch::IntegrationTest
  Topic::ALL.each do |topic|
    topic.levels.each do |details|
      %w[ practice mixed ].each do |mode|
        test "#{topic.key} level #{details[:number]} #{mode} issues questions that can all be saved" do
          user = users(:ada)
          level = details[:number]
          unlock(user, topic, level)
          sign_in_as user

          get play_path(topic.slug, **(mode == "mixed" ? { mixed: 1 } : { level: level }))
          assert_response :success
          node = css_select("[data-test-question-sets-value]").first
          assert_equal level.to_s, node["data-test-level-value"]
          assert_equal mode, node["data-test-mode-value"]
          set = JSON.parse(node["data-test-question-sets-value"]).first
          assert_equal User::Practisable::QUESTION_COUNT, set["questions"].size
          facts = set["questions"].map { |question| topic.fact_key(question) }.uniq
          if mode == "practice"
            assert_empty facts - topic.facts(level), "practice asks only this level's facts"
          elsif (earlier = topic.facts_through(level) - topic.facts(level)).any?
            assert (facts & earlier).any?, "mixed games include earlier skills"
          end

          # Submit the whole issued set to exercise every question, not just a valid prefix.
          results = set["questions"].map do |question|
            assert_empty question["answer"].delete("0-9").chars - topic.keys(level)
            question.except("text", "answer").merge("given" => question["answer"], "ms" => 100)
          end
          post attempts_path, params: { attempt: { topic: topic.key, level: level,
            client_id: set["id"], ticket: set["ticket"], results: results } }, as: :json
          assert_response :created
          attempt = user.attempts.find_by!(client_id: set["id"])
          assert_equal [ topic.key, level, mode, results.size ], [ attempt.topic, attempt.level, attempt.mode, attempt.correct ]
          get response.parsed_body["url"]
          assert_response :success
        end
      end
    end
  end
end
