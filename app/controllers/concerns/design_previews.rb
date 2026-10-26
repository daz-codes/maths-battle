# Local design comparisons: a browser preference, separate from the player's saved light/dark setting.
# Preview templates never replace the production screens
module DesignPreviews
  extend ActiveSupport::Concern

  DESIGNS = {
    "original" => { name: "Original", description: "The current design" },
    "sprint" => { name: "Sprint", description: "Sporting blue. Clear and focused." },
    "bunch" => { name: "Bunch", description: "Warm yellow. A little more playful." },
    "arcade" => { name: "Arcade", description: "After-dark energy. Electric lime." }
  }.freeze

  included do
    before_action :prepare_design_preview
    helper_method :design_previews_available?, :design_preview, :design_preview?
  end

  private
    def design_previews_available?
      Rails.env.development? || Rails.env.test?
    end

    def design_preview
      return "original" unless design_previews_available?

      @design_preview || "original"
    end

    def design_preview?
      design_preview != "original"
    end

    def prepare_design_preview
      return unless design_previews_available?

      requested = params[:design]
      if DESIGNS.key?(requested)
        cookies[:design_preview] = { value: requested, expires: 30.days.from_now, httponly: true, same_site: :lax }
      end
      @design_preview = cookies[:design_preview].presence_in(DESIGNS.keys) || "original"
      prepend_view_path Rails.root.join("app/views/design_previews") if design_preview?
    end
end
