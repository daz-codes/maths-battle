require "test_helper"

# The error pages are static, so they show even when the app can't, but they're written from the app's own
# logo by bin/rails errors:pages. If this fails after changing the page or the logo, run that
class ErrorPagesTest < ActiveSupport::TestCase
  test "each error page has the header, says what happened kindly, and has a way home" do
    ErrorPage::ALL.each do |code, page|
      title, message = page.values_at(:title, :message)
      html = ErrorPage.path(code).read
      assert_includes html, %(<a class="logo" aria-label="MatheMinute home" href="/">), code
      assert_includes html, "logo__minute", code
      assert_includes html, "<h1>#{ERB::Util.html_escape(title)}</h1>", code
      assert_includes html, ERB::Util.html_escape(message), code
      assert_includes html, %(<a class="button" href="/">Back to home</a>), code
    end
  end
end
