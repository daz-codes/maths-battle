require "test_helper"

class DesignPreviewsTest < ActionDispatch::IntegrationTest
  test "a visitor can preview each design without making an account" do
    choose_topic
    assert_no_difference "User.count" do
      %w[ sprint bunch arcade original ].each do |design|
        get root_path, params: { design: design }
        assert_response :success
        assert_select "html[data-design=?]", design
        assert_select "nav[aria-label='Design previews'] a", 4
        assert_select ".design-picker__option[aria-current=true]", text: /#{design.capitalize}/
      end
    end
  end

  test "a design follows navigation but does not overwrite saved colour preferences" do
    user = users(:ada)
    user.update!(theme: "dark")
    sign_in_as user
    get root_path, params: { design: "sprint" }

    [ practice_path, challenge_path, groups_path, stats_path, awards_path, edit_profile_path, play_path("times-tables") ].each do |path|
      get path
      assert_response :success
      assert_select "html[data-theme=dark][data-design=sprint]"
    end
    assert_equal "dark", user.reload.theme
    assert_select ".design-picker", count: 0, message: "the switcher stays out of a running game"
  end

  test "unknown designs are ignored and original restores the existing screen" do
    choose_topic
    get root_path, params: { design: "arcade" }
    get root_path, params: { design: "<script>alert(1)</script>" }
    assert_select "html[data-design=arcade]"
    get root_path, params: { design: "original" }
    assert_select "body.design-preview", count: 0
    assert_select ".greeting .streak"
    assert_select ".site-footer__start"
  end

  test "switching preserves other query parameters" do
    sign_in_as users(:ada)
    get stats_path("times-tables"), params: { level: 1, design: "sprint" }
    assert_select ".design-picker__option[href=?]", "/stats/times-tables?design=bunch&level=1"
  end
end
