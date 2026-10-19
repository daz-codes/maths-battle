require "test_helper"

class AvatarsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:ada)
    @user.update!(avatar_upload: fixture_file_upload("photo.jpg", "image/jpeg"))
  end

  test "only the current player's avatar is served and it cannot be cached" do
    sign_in_as @user
    get avatar_path
    assert_response :success
    assert_equal "image/webp", response.media_type
    assert_equal @user.avatar.download, response.body.b
    assert_includes response.headers["Cache-Control"], "private"
    assert_includes response.headers["Cache-Control"], "no-store"

    sign_in_as users(:bob)
    get avatar_path
    assert_response :not_found
  end

  test "visitors cannot download an avatar" do
    get avatar_path
    assert_redirected_to new_session_path
  end

  test "public blob and disk routes are disabled even with a valid signed token" do
    get "/rails/active_storage/blobs/redirect/#{@user.avatar.blob.signed_id}/avatar.webp"
    assert_response :not_found
    key = ActiveStorage.verifier.generate({ key: @user.avatar.blob.key, service_name: "test", content_type: "image/webp", disposition: "inline" },
      purpose: :blob_key, expires_in: 5.minutes)
    get "/rails/active_storage/disk/#{key}/avatar.webp"
    assert_response :not_found
  end

  test "anonymous direct uploads are disabled even with a valid CSRF token" do
    ActionController::Base.allow_forgery_protection = true
    get topics_path
    token = css_select('meta[name="csrf-token"]').first["content"]
    assert_no_difference -> { ActiveStorage::Blob.count } do
      post "/rails/active_storage/direct_uploads", params: { blob: {
        filename: "unprocessed.txt", byte_size: 12, checksum: Digest::MD5.base64digest("not a photo!"), content_type: "text/plain"
      } }, headers: { "X-CSRF-Token" => token }, as: :json
    end
    assert_response :not_found
  ensure
    ActionController::Base.allow_forgery_protection = false
  end
end
