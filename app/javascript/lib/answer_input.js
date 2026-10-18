// What can be typed into an answer, the same in the game and in tutorials: digits always, a minus sign
// first, a decimal point or fraction line once and after a digit: -0.42, 11/9. Extra keys are the level's
export function allowedKey(typed, key, extraKeys) {
  if (/^[0-9]$/.test(key)) return true
  if (!extraKeys.includes(key)) return false
  if (key === "-") return typed === ""
  return /[0-9]$/.test(typed) && !/[./]/.test(typed)
}

// What typing a key makes the answer, or null if it can't go there. A decimal point with no digit before it
// starts the number with 0, so .2 types 0.2 and −.2 types −0.2
export function typedWith(typed, key, extraKeys) {
  if (key === "." && extraKeys.includes(".") && (typed === "" || typed === "-")) return `${typed}0.`
  return allowedKey(typed, key, extraKeys) ? typed + key : null
}

// A finished answer ends in a digit: "0." or "−" is still being typed
export function finished(typed) {
  return /[0-9]$/.test(typed)
}

// As shown, with a proper minus sign: −56
export function shown(typed) {
  return typed.replace("-", "−")
}
