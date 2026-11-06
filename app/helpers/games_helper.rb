module GamesHelper
  EXTRA_KEYS = { "." => [ ".", "Decimal point" ] }
  POWER_UP_ICONS = { "double" => :double, "shield" => :shield, "time" => :time, "freeze" => :freeze, "reset" => :breaker, "scramble" => :mixed }

  def power_up_icons
    POWER_UP_ICONS
  end

  def keypad_key(digit, label: digit, aria: nil, modifier: nil, controller: "test")
    tag.button(label, type: "button", class: [ "keypad__key", (modifier && "keypad__key--#{modifier}") ],
      data: { action: "pointerdown->#{controller}#tap click->#{controller}#tap", digit: digit }, aria: { label: aria })
  end

  def extra_keypad_key(key, controller: "test")
    label, aria = EXTRA_KEYS.fetch(key)
    keypad_key(key, label: label, aria: aria, modifier: "extra", controller: controller)
  end

  def delete_key(controller: "test")
    keypad_key("back", label: "⌫", aria: "Delete", modifier: "back", controller: controller)
  end
end
