require "test_helper"

class AppearanceTest < ActionDispatch::IntegrationTest
  test "the Arcade layout is the normal interface without a preview parameter or account" do
    choose_topic
    assert_no_difference "User.count" do
      get root_path
      assert_select "body.app-shell"
      assert_select ".ui-home__heading", text: /One minute.*All in/m
      assert_select ".ui-header .ui-brand"
      assert_select ".ui-navigation a", 5
      assert_select "html[data-design], .design-picker", count: 0
    end
  end

  test "saved appearance preferences and browser colours are honoured on every screen" do
    user = users(:ada)
    sign_in_as user
    %w[ light dark system ].each do |theme|
      user.update!(theme: theme)
      [ root_path, practice_path, challenge_path, groups_path, stats_path, awards_path, edit_profile_path, play_path("times-tables") ].each do |path|
        get path
        assert_response :success
        assert_select "html[data-theme=?]", theme
        assert_select "body[data-theme-preference-value=?]", theme
        %w[ light dark ].each do |scheme|
          expected = ApplicationHelper::THEME_COLOURS.fetch(theme == "system" ? scheme : theme)
          assert_select "meta[name=theme-color][data-theme-color=?][content=?]", scheme, expected
        end
      end
    end
  end

  test "the production interface ignores old preview links and cookies" do
    choose_topic
    cookies[:design_preview] = "bunch"
    environment = Rails.env
    begin
      Rails.env = "production"
      get root_path, params: { design: "sprint" }
      assert_select "body.app-shell .ui-home__heading", text: /All in/
      assert_select "html[data-design], .design-picker", count: 0
    ensure
      Rails.env = environment
    end
  end
end
