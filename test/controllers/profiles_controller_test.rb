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
