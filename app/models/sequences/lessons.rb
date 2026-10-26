# A minute's tutorial for each sequences level, like TimesTables::Lessons. The one to try is a question as the topic
# asks it, so Sequences.worked writes out its terms and works out the next
module Sequences::Lessons
  ALL = {
    1 => {
      steps: [
        { show: "3, 7, 11, 15, 19, …", say: "Find the next term by spotting the pattern" },
        { show: "+4  +4  +4  +4", say: "Look at the gaps: here it goes up by 4 each time" },
        { show: "19 + 4 = 23", say: "So add 4 once more" },
        { show: "50, 43, 36, 29, 22, …", say: "Going down works the same way: take 7 each time, so 15 is next" }
      ],
      try: { question: { type: "add", a: 5, b: 6, c: 0 }, hint: "The gap is 6 each time" }
    },
    2 => {
      steps: [
        { show: "4, 6, 10, 16, 24, …", say: "When the gaps change, look at how they change" },
        { show: "+2  +4  +6  +8", say: "The gaps grow by 2 each time" },
        { show: "24 + 10 = 34", say: "So the next gap is 10" },
        { show: "2, 5, 10, 17, 26, …", say: "Square numbers plus one: 1, 4, 9, 16, 25, then 36 + 1 = 37" }
      ],
      try: { question: { type: "quadratic", a: 3, b: 2, c: 2 }, hint: "The gaps are 2, 4, 6, 8, so the next is 10" }
    },
    3 => {
      steps: [
        { show: "3, 6, 12, 24, 48, …", say: "If the gaps keep growing, try dividing instead" },
        { show: "×2  ×2  ×2  ×2", say: "Each term is double the one before" },
        { show: "48 × 2 = 96", say: "So double once more" },
        { show: "192, 96, 48, 24, 12, …", say: "Halving works the same way: 12 ÷ 2 = 6" }
      ],
      try: { question: { type: "times", a: 2, b: 3, c: 0 }, hint: "Each term is 3 times the one before" }
    },
    4 => {
      steps: [
        { show: "2, 5, 7, 12, 19, …", say: "Here each term is the two before it added" },
        { show: "2 + 5 = 7", say: "2 and 5 make 7" },
        { show: "5 + 7 = 12", say: "Then 5 and 7 make 12, and 7 and 12 make 19" },
        { show: "12 + 19 = 31", say: "So the next is 12 + 19" }
      ],
      try: { question: { type: "fibonacci", a: 1, b: 3, c: 0 }, hint: "Add the last two: 7 + 11" }
    },
    5 => {
      steps: [
        { show: "4, 9, 11, 16, 18, …", say: "Sometimes two steps take turns" },
        { show: "+5  +2  +5  +2", say: "Up 5, then up 2, then up 5 again" },
        { show: "18 + 5 = 23", say: "The next step is +5" }
      ],
      try: { question: { type: "alternate", a: 10, b: 3, c: -1 }, hint: "Up 3, then down 1, taking turns" }
    }
  }
end
