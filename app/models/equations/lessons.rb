# A minute's tutorial for each equations level, like TimesTables::Lessons. The one to try is a question as the
# topic asks it, so Equations.worked writes it out (fractions stacked) and solves it
module Equations::Lessons
  ALL = {
    1 => {
      steps: [
        { show: "x + 4 = 9", say: "Find the number x stands for" },
        { show: "x + 4 − 4 = 9 − 4", say: "Do the opposite to both sides: take away 4" },
        { show: "x = 5", say: "Check it: 5 + 4 = 9 ✓" },
        { show: "3x = 12, so x = 4", say: "3x means 3 × x, so the opposite is to divide by 3" }
      ],
      try: { question: { type: "x-a=b", a: 3, b: 8 }, hint: "The opposite of taking away 3 is adding 3 to both sides" }
    },
    2 => {
      steps: [
        { show: "12x = 96", say: "Bigger numbers, the same idea" },
        { show: "x = 96 ÷ 12", say: "Undo × 12 by dividing both sides by 12" },
        { show: "x = 8", say: "Check it: 12 × 8 = 96 ✓" },
        { show: "15 = x − 7", say: "Sometimes x is on the right. It works the same way: x = 22" }
      ],
      try: { question: { type: "x/a=b", a: 6, b: 7, flip: true }, hint: "Undo ÷ 6 by multiplying both sides by 6" }
    },
    3 => {
      steps: [
        { show: "2x + 3 = 11", say: "Two steps: undo the + 3 first, then the × 2" },
        { show: "2x = 8", say: "Take away 3 from both sides" },
        { show: "x = 4", say: "Divide both sides by 2" },
        { show: "2 × 4 + 3 = 11 ✓", say: "Check it by putting 4 back in" }
      ],
      try: { question: { type: "ax-b=c", a: 5, b: 2, c: 13 }, hint: "Add 2 to both sides first, then divide by 5" }
    },
    4 => {
      steps: [
        { show: "4(x + 3) = 36", say: "Everything in the bracket is multiplied by 4" },
        { show: "x + 3 = 9", say: "So divide both sides by 4 first" },
        { show: "x = 6", say: "Then take away 3" },
        { show: "(x + 3)/5 = 2, so x + 3 = 10", say: "Dividing works the same way: multiply first, so x = 7" }
      ],
      try: { question: { type: "a(x+b)=c", a: 3, b: 2, c: 21 }, hint: "Divide both sides by 3 first, then take away 2" }
    },
    5 => {
      steps: [
        { show: "12x = 9", say: "The answer won't always be a whole number" },
        { show: "x = 9/12", say: "Divide both sides by 12, writing it as a fraction" },
        { show: "x = 3/4", say: "Simplify: 9 and 12 both divide by 3" },
        { show: "9x = 11, so x = 11/9", say: "Top-heavy is fine: type it as 11/9" }
      ],
      try: { question: { type: "ax=b", a: 8, b: 6 }, hint: "x = 6/8, then simplify: 6 and 8 both divide by 2" }
    }
  }
end
