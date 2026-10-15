# Light, dark, or following the device
module User::Themeable
  extend ActiveSupport::Concern

  THEMES = %w[ system light dark ]

  included do
    validates :theme, inclusion: { in: THEMES }
  end
end
