// What can be typed into an answer, the same in the game and in tutorials: digits always, a minus sign
// first, a decimal point or fraction line once and after a digit: -0.42, 11/9. Extra keys are the level's
export function allowedKey(typed, key, extraKeys) {
  if (/^[0-9]$/.test(key)) return true
  if (!extraKeys.includes(key)) return false
  if (key === "-") return typed === ""
  return /[0-9]$/.test(typed) && !/[./]/.test(typed)
}

// As shown, with a proper minus sign: −56
export function shown(typed) {
  return typed.replace("-", "−")
}
