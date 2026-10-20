# A minute's tutorial for each percentages level, like TimesTables::Lessons. The one to try is a question as the
# topic asks it, so Percentages.worked writes it out and works it out
module Percentages::Lessons
  ALL = {
    1 => {
      steps: [
        { show: "50% of 60", say: "Per cent means out of 100, so 50% is a half" },
        { show: "60 ÷ 2 = 30", say: "To find 50%, halve it" },
        { show: "10% of 70", say: "10% is a tenth" },
        { show: "70 ÷ 10 = 7", say: "To find 10%, divide by 10" }
      ],
      try: { question: { type: "10", a: 10, b: 90 }, hint: "Divide 90 by 10" }
    },
    2 => {
      steps: [
        { show: "5% of 80", say: "5% is half of 10%" },
        { show: "10% of 80 = 8", say: "Find 10% first" },
        { show: "5% of 80 = 4", say: "Then halve it" },
        { show: "25% of 48 = 12", say: "25% is a quarter: halve, then halve again. 48, 24, 12" }
      ],
      try: { question: { type: "25", a: 25, b: 40 }, hint: "Halve 40, then halve it again" }
    },
    3 => {
      steps: [
        { show: "15% of 60", say: "Build it from ones you know: 15% is 10% and 5%" },
        { show: "10% of 60 = 6", say: "Find 10%" },
        { show: "5% of 60 = 3", say: "Halve that for 5%" },
        { show: "15% of 60 = 9", say: "Add them together: 6 + 3" }
      ],
      try: { question: { type: "fives", a: 30, b: 80 }, hint: "30% is three lots of 10%. 10% of 80 is 8" }
    },
    4 => {
      steps: [
        { show: "1% of 700", say: "1% is a hundredth" },
        { show: "700 ÷ 100 = 7", say: "To find 1%, divide by 100" },
        { show: "1% of 1200 = 12", say: "Take two zeroes off the end" },
        { show: "3% of 700 = 21", say: "And 3% is three lots of 1%" }
      ],
      try: { question: { type: "1", a: 1, b: 900 }, hint: "Divide 900 by 100" }
    },
    5 => {
      steps: [
        { show: "37% of 300", say: "Any percentage: build it from 10% and 1%" },
        { show: "30% of 300 = 90", say: "10% is 30, so 30% is 90" },
        { show: "7% of 300 = 21", say: "1% is 3, so 7% is 21" },
        { show: "37% of 300 = 111", say: "Add them together: 90 + 21" }
      ],
      try: { question: { type: "any", a: 12, b: 400 }, hint: "10% of 400 is 40, and 1% is 4. 12% is 10% and 2%" }
    }
  }
end
