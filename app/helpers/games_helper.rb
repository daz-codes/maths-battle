module GamesHelper
  EXTRA_KEYS = { "/" => [ "/", "Fraction" ], "." => [ ".", "Decimal point" ], "-" => [ "−", "Minus" ] }

  def keypad_key(digit, label: digit, aria: nil, modifier: nil)
    tag.button(label, type: "button", class: [ "keypad__key", (modifier && "keypad__key--#{modifier}") ],
      data: { action: "pointerdown->test#tap", digit: digit }, aria: { label: aria })
  end

  def extra_keypad_key(key)
    label, aria = EXTRA_KEYS.fetch(key)
    keypad_key(key, label: label, aria: aria, modifier: "extra")
  end

  def delete_key
    keypad_key("back", label: "⌫", aria: "Delete", modifier: "back")
  end
end
