require "test_helper"
require "rack/builder"

class RackBootTest < ActiveSupport::TestCase
  test "the deployment entry point boots through Rack" do
    app = Rack::Builder.parse_file(Rails.root.join("config.ru").to_s)
    response = Rack::MockRequest.new(app).get("/up", "HTTP_HOST" => "www.example.com")
    assert_equal 200, response.status
  end
end
