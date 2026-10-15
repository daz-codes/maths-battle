# British or American wording. There's no country lookup, so the browser's preferred language decides:
# phones and computers set to the UK send en-GB, and get "maths"; everyone else gets "math"
module Localisable
  extend ActiveSupport::Concern

  included do
    helper_method :maths
  end

  private
    def maths
      british? ? "maths" : "math"
    end

    def british?
      preferred_region == "GB"
    end

    # "en-GB,en;q=0.9" → "GB"
    def preferred_region
      request.headers["Accept-Language"].to_s.split(/[,;]/).first.to_s.split(/[-_]/).second&.upcase
    end
end
