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
      assert_select ".collection .freezes"
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
    assert_select ".greeting img.avatar"
  end

  test "without a picture the home page shows a letter" do
    @user.update!(name: "Ada")
    get root_path
    assert_select ".greeting .avatar--letter", text: "A"
  end

  test "registered players sign out from settings" do
    get edit_profile_path
    assert_select "form[action=?] button", session_path, text: "Sign out"
  end

  test "the footer shows the player and links to settings and stats" do
    get root_path
    assert_select ".site-footer a.site-footer__player[href=?][aria-label=Settings]", edit_profile_path
    assert_select ".site-footer a.site-footer__name[href=?]", edit_profile_path, text: "ada"
    assert_select ".site-footer .site-footer__stars", text: "0 ⭐"
    assert_select ".site-footer a.site-footer__player .avatar"
    assert_select ".site-footer a.site-footer__stats[href=?] svg.stats-icon", stats_path
    assert_select ".site-footer a.site-footer__home[href=?]", root_path, text: "Home"
    assert_select ".site-footer a.site-footer__home svg.footer-icon"
    assert_select ".site-footer a.site-footer__awards[href=?]", awards_path, text: "Awards"
    assert_select ".site-footer", text: /Settings/, count: 0
  end

  test "shows the player's stars and streak freezes, and buys a freeze with stars" do
    get edit_profile_path
    assert_select ".collection .stars-total", text: "0 ⭐ stars"
    assert_select ".freezes__held", text: /No streak freezes/
    assert_select ".freezes__hint", text: /Get 10,000 more ⭐ to buy one/

    @user.attempts.create!(topic: "times_tables", results: []).update_column(:stars, 10_100)
    get edit_profile_path
    assert_select "form[action=?] button", streak_freeze_path, text: "Buy one for 10,000 ⭐"

    post streak_freeze_path
    assert_redirected_to edit_profile_path
    follow_redirect!
    assert_select ".flash", text: /You bought a streak freeze/
    assert_select ".freezes__held", text: /1 streak freeze/
    assert_select ".collection .stars-total", text: "100 ⭐ stars"
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
