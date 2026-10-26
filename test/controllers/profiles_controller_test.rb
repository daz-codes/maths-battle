require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:ada)
    sign_in_as @user
  end

  test "edit" do
    get edit_profile_path
    assert_response :success
    assert_select "input[type=radio][name='user[theme]']", 3
  end

  test "in three parts: about you, the game, and app settings" do
    get edit_profile_path

    assert_equal [ "About you", "Game", "App settings" ], css_select(".settings__heading").map(&:text)
    assert_select "section[aria-labelledby=about-you] form" do
      assert_select "input[name='user[name]']"
      assert_select "input[name='user[avatar_upload]']"
      assert_select "input[type=submit][value=Save]"
    end
    assert_select "section[aria-labelledby=your-game]" do
      assert_select "a.current-topic"
      assert_select ".freezes", count: 0
    end
    assert_select "section[aria-labelledby=app-settings]" do
      assert_select ".reminder"
      assert_select "form[data-controller=autosave] input[name='user[theme]']", 3
      assert_select "form[data-controller=autosave] input[name='user[sounds]']", 2
    end
  end

  test "app settings save as they're changed, staying on the page" do
    patch profile_path, params: { user: { theme: "dark" } }, as: :json
    assert_response :no_content
    assert_equal "dark", @user.reload.theme

    patch profile_path, params: { user: { theme: "purple" } }, as: :json
    assert_response :unprocessable_entity
    assert_equal "dark", @user.reload.theme
  end

  test "sounds and vibration are on until turned off, and every page says which" do
    get edit_profile_path
    assert_select "html[data-sounds=on]"
    assert_select "fieldset[data-controller=sounds] input[type=radio][name='user[sounds]'][value=true][checked]"

    patch profile_path, params: { user: { sounds: "false" } }
    assert_not @user.reload.sounds?
    get root_path
    assert_select "html[data-sounds=off]"
  end

  test "changes name and theme" do
    patch profile_path, params: { user: { name: "Ada L", theme: "dark" } }

    assert_redirected_to root_path
    assert_equal [ "Ada L", "dark" ], [ @user.reload.name, @user.theme ]

    follow_redirect!
    assert_select "html[data-theme=dark]"
  end

  test "uploads a picture, shown on the home page" do
    patch profile_path, params: { user: { avatar_upload: fixture_file_upload("photo.jpg", "image/jpeg") } }
    assert_redirected_to root_path
    assert @user.reload.avatar.attached?

    @user.update!(name: "Ada")
    get root_path
    assert_select ".site-header img.avatar"
  end

  test "without a picture the home page shows a letter" do
    @user.update!(name: "Ada")
    get root_path
    assert_select ".site-header .avatar--letter", text: "A"
  end

  test "registered players sign out from settings" do
    get edit_profile_path
    assert_select "form[action=?] button", session_path, text: "Sign out"
  end

  test "the header links the player's avatar to settings and the footer keeps the main destinations" do
    get root_path
    assert_select ".site-header a.ui-profile[href=?][aria-label=Settings]", edit_profile_path
    assert_select ".site-footer .site-footer__gems", count: 0
    assert_select ".site-header a.ui-profile .avatar"
    assert_select ".site-footer a.site-footer__stats[href=?] svg.icon--stats", stats_path
    assert_select ".site-footer a.site-footer__home[href=?]", root_path, text: "Home"
    assert_select ".site-footer a.site-footer__home svg.footer-icon"
    assert_select ".site-footer a.site-footer__awards[href=?]", awards_path, text: "Awards"
    assert_select ".site-footer", text: /Settings/, count: 0
  end

  test "settings show no gems or streak freezes, and one can't be bought while they're put away" do
    @user.attempts.create!(topic: "times_tables", results: []).update_column(:gems, 10_100)
    get edit_profile_path
    assert_select ".gems-total, .freezes", count: 0
    assert_select "form[action=?]", streak_freeze_path, count: 0

    post streak_freeze_path
    assert_redirected_to edit_profile_path
    assert_equal 0, @user.reload.streak_freezes
  end

  test "rejects unknown themes" do
    patch profile_path, params: { user: { theme: "purple" } }
    assert_response :unprocessable_entity
    assert_equal "system", @user.reload.theme
  end

  test "pages follow the device's theme by default" do
    get root_path
    assert_select "html[data-theme=system]"
  end
end
