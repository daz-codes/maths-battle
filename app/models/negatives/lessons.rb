# A minute's tutorial for each negative numbers level, like TimesTables::Lessons. The one to try is a question as
# the topic asks it, so Negatives.worked writes it out and works it out
module Negatives::Lessons
  ALL = {
    1 => {
      steps: [
        { show: "4 − 9", say: "Taking away more than you have goes below zero" },
        { show: "4 − 4 = 0", say: "Take away 4 to get down to zero" },
        { show: "9 − 4 = 5", say: "That leaves 5 more to take away" },
        { show: "4 − 9 = −5", say: "So you end up 5 below zero" }
      ],
      try: { question: { type: "below-zero", a: 3, b: 8 }, hint: "Get to zero first, then go 5 more below" }
    },
    2 => {
      steps: [
        { show: "−4 + 2", say: "Starting below zero, like a cold day on a thermometer" },
        { show: "−4 + 2 = −2", say: "Adding goes up: 2 up from −4 is −2" },
        { show: "−3 + 5 = 2", say: "Go up past zero: 3 to get to zero, then 2 more" },
        { show: "−2 − 9 = −11", say: "Taking away goes down: further below zero" }
      ],
      try: { question: { type: "from-negative", a: -6, b: 4 }, hint: "Start at −6 and go up 4" }
    },
    3 => {
      steps: [
        { show: "−3 + (−4)", say: "Adding a negative number" },
        { show: "−3 − 4", say: "Adding a negative is the same as taking away" },
        { show: "−3 + (−4) = −7", say: "Go down 4 from −3" },
        { show: "5 + (−8) = −3", say: "It works from above zero too: 5 − 8" }
      ],
      try: { question: { type: "add-negative", a: -2, b: -5 }, hint: "Adding −5 is taking away 5" }
    },
    4 => {
      steps: [
        { show: "−5 − (−7)", say: "Taking away a negative number" },
        { show: "−5 + 7", say: "Two minus signs together make a plus" },
        { show: "−5 − (−7) = 2", say: "Go up 7 from −5" },
        { show: "3 − (−4) = 7", say: "3 + 4 = 7" }
      ],
      try: { question: { type: "subtract-negative", a: -1, b: -6 }, hint: "Taking away −6 is adding 6" }
    },
    5 => {
      steps: [
        { show: "−6 × 4", say: "Multiplying: do the table fact, then work out the sign" },
        { show: "6 × 4 = 24", say: "Without the signs it's 24" },
        { show: "−6 × 4 = −24", say: "One minus sign: the answer is negative" },
        { show: "−24 ÷ (−6) = 4", say: "Two minus signs cancel out, for dividing too" }
      ],
      try: { question: { type: "multiply", a: -7, b: 8 }, hint: "7 × 8 = 56. How many minus signs are there?" }
    }
  }
end
