require "test_helper"

class PwaTest < ActionDispatch::IntegrationTest
  test "manifest" do
    get pwa_manifest_path(format: :json)

    assert_response :success
    manifest = response.parsed_body
    assert_equal "standalone", manifest["display"]
    assert_equal %w[192x192 512x512], manifest["icons"].map { _1["sizes"] }.uniq
    assert_equal "One minute of times tables, equations, functions or simultaneous equations a day. Keep your streak going!", manifest["description"]
  end

  test "service worker" do
    get pwa_service_worker_path(format: :js)

    assert_response :success
    assert_match "offline.html", response.body
  end
end
