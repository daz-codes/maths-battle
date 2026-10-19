# A minute's tutorial for each fractions level, like TimesTables::Lessons. The one to try is a question as the
# topic asks it, so Fractions.worked writes it out (stacked) and works it out
module Fractions::Lessons
  ALL = {
    1 => {
      steps: [
        { show: "6/8", say: "To simplify a fraction, find a number that divides into the top and the bottom" },
        { show: "6 ÷ 2 = 3, 8 ÷ 2 = 4", say: "2 goes into 6 and into 8" },
        { show: "6/8 = 3/4", say: "Nothing else goes into 3 and 4, so it's as simple as it gets" },
        { show: "12/18 = 2/3", say: "Use the biggest number that goes into both: here it's 6" }
      ],
      try: { question: { type: "simplify", a: 10, b: 15 }, hint: "5 goes into 10 and 15" }
    },
    2 => {
      steps: [
        { show: "2/7 + 3/7", say: "When the bottoms are the same, they're the same size pieces" },
        { show: "2 + 3 = 5", say: "So just add the tops" },
        { show: "2/7 + 3/7 = 5/7", say: "The bottom stays the same" },
        { show: "3/8 + 1/8 = 4/8 = 1/2", say: "Always simplify the answer if you can" }
      ],
      try: { question: { type: "sub-same", a: 7, b: 9, c: 4, d: 9 }, hint: "Take away the tops: 7 − 4. The bottom stays 9" }
    },
    3 => {
      steps: [
        { show: "1/3 + 1/4", say: "Different bottoms: first make them the same" },
        { show: "3 × 4 = 12", say: "Find a number both go into: 12" },
        { show: "4/12 + 3/12", say: "1/3 is 4/12 and 1/4 is 3/12" },
        { show: "4/12 + 3/12 = 7/12", say: "Now add the tops, as before" }
      ],
      try: { question: { type: "add-diff", a: 1, b: 2, c: 1, d: 6 }, hint: "1/2 is 3/6. Then add, and simplify the answer" }
    },
    4 => {
      steps: [
        { show: "2/3 × 3/5", say: "To multiply fractions, you don't need the same bottoms" },
        { show: "2 × 3 = 6", say: "Multiply the tops" },
        { show: "3 × 5 = 15", say: "Multiply the bottoms" },
        { show: "6/15 = 2/5", say: "Then simplify: 3 goes into 6 and 15" }
      ],
      try: { question: { type: "multiply", a: 3, b: 4, c: 1, d: 2 }, hint: "Tops: 3 × 1. Bottoms: 4 × 2" }
    },
    5 => {
      steps: [
        { show: "3/4 ÷ 1/2", say: "To divide by a fraction, turn it upside down and multiply" },
        { show: "3/4 × 2/1", say: "1/2 upside down is 2/1" },
        { show: "3 × 2 = 6, 4 × 1 = 4", say: "Multiply the tops and the bottoms" },
        { show: "6/4 = 3/2", say: "Simplify. It's more than one, so it stays top-heavy" }
      ],
      try: { question: { type: "divide", a: 2, b: 5, c: 1, d: 3 }, hint: "Turn 1/3 upside down: 2/5 × 3/1" }
    }
  }
end
