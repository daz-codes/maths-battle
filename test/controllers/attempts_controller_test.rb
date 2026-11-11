require "test_helper"

class AttemptsControllerTest < ActionDispatch::IntegrationTest
  test "a visitor's first game makes them a guest and saves it" do
    assert_difference -> { User.count } => 1, -> { Attempt.count } => 1 do
      post attempts_path, params: game_upload(rights: [ true, true, false, true ]), as: :json
    end
    assert_response :created
    attempt = Attempt.last
    assert_equal 40, attempt.score
    get JSON.parse(response.body)["url"]
    assert_response :success
    assert_select ".card__number", text: "40"
  end

  test "a solo power-up claimed counts" do
    powers = [ "double" ] * PowerUp::MOST
    post attempts_path, params: game_upload(rights: [ true ] * 12, powers: powers, claims: [ { drop: 1, at: 3 } ]), as: :json
    assert_response :created
    assert_equal (1..12).sum * 10 + 10 * 5, Attempt.last.score
  end

  test "a game that doesn't match its ticket is refused" do
    upload = game_upload
    upload[:attempt][:results][0]["a"] = "99"
    post attempts_path, params: upload, as: :json
    assert_response :unprocessable_entity
    assert_match "don't match", JSON.parse(response.body)["error"]
  end

  test "another browser's ticket is refused" do
    post attempts_path, params: game_upload(owner: "someone-else"), as: :json
    assert_response :unprocessable_entity
  end

  test "a result belongs to its player" do
    attempt = play(users(:bob))
    sign_in_as users(:ada)
    get attempt_path(attempt)
    assert_response :not_found
  end
end
