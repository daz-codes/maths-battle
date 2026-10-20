# The static error pages in public/, which show even when the app can't. They're written from the app's own
# header and logo (app/views/errors/page) by bin/rails errors:pages: run it after changing either.
# What each says is kept short and kind, as it's usually not the player's fault
module ErrorPage
  ALL = {
    400 => { emoji: "🤔", title: "That didn't work", message: "Something about that request wasn't right. Head back home and try again." },
    404 => { emoji: "🔍", title: "We couldn't find that page", message: "It may have moved, or the link might not be quite right." },
    422 => { emoji: "🔄", title: "That didn't go through", message: "The page may have been open a while. Go back, refresh, and try again." },
    500 => { emoji: "😬", title: "Something went wrong", message: "Sorry, that's on our side, not yours. Try again in a moment, or head back home." }
  }

  def self.write_all
    ALL.each do |code, page|
      html = ApplicationController.render(template: "errors/page", layout: false, locals: { code:, **page })
      path(code).write(html)
    end
  end

  def self.path(code)
    Rails.public_path.join("#{code}.html")
  end
end
