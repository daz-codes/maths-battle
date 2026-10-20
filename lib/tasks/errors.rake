namespace :errors do
  desc "Writes the static error pages in public/ from app/views/errors/page, so they look like the app"
  task pages: :environment do
    ErrorPage.write_all
    ErrorPage::ALL.each_key { |code| puts ErrorPage.path(code).relative_path_from(Rails.root) }
  end
end
