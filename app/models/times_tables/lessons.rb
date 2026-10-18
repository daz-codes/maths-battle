# A minute's tutorial for each times tables level: a worked example in steps to tap through, each a line of
# maths to show (or several) and a few words to say about it, then one to try, with a hint. The one to try is
# a question as the topic asks it, so the topic writes it out and works out the answer (TimesTables.worked)
module TimesTables::Lessons
  ALL = {
    1 => {
      steps: [
        { show: "4 × 3", say: "means 4 lots of 3" },
        { show: "3, 6, 9, 12", say: "Count up in 3s, four times" },
        { show: "4 × 3 = 12", say: "The last number you say is the answer" },
        { show: "3 × 4 = 12", say: "It works either way round" }
      ],
      try: { question: { a: 5, b: 3 }, hint: "Count up in 3s, five times: 3, 6, 9…" }
    },
    2 => {
      steps: [
        { show: "7 × 8", say: "Too many to count? Split it into ones you know" },
        { show: "7 × 5 = 35", say: "8 is 5 + 3, so start with 7 lots of 5" },
        { show: "7 × 3 = 21", say: "Then 7 lots of 3" },
        { show: "35 + 21 = 56", say: "Add them together: 7 × 8 = 56" }
      ],
      try: { question: { a: 6, b: 7 }, hint: "6 × 5 = 30. Then add 6 × 2" }
    },
    3 => {
      steps: [
        { show: "40 × 300", say: "Numbers with zeroes on the end" },
        { show: "4 × 3 = 12", say: "Cover up the zeroes and do the table fact" },
        { show: "40 × 300", say: "Count the zeroes: one in 40, two in 300. That's three" },
        { show: "40 × 300 = 12000", say: "Put all three back on the end of 12" }
      ],
      try: { question: { a: 60, b: 70 }, hint: "6 × 7 = 42, and there are two zeroes" }
    },
    4 => {
      steps: [
        { show: "0.7 × 3000", say: "A decimal and zeroes together" },
        { show: "7 × 3 = 21", say: "Start with the table fact" },
        { show: "3 zeroes, 1 decimal place", say: "Each decimal place cancels out a zero, leaving two zeroes" },
        { show: "0.7 × 3000 = 2100", say: "21 with two zeroes on the end" }
      ],
      try: { question: { a: "0.4", b: "0.6" }, hint: "4 × 6 = 24, and there are two decimal places to put back" }
    },
    5 => {
      steps: [
        { show: "−6 × 4", say: "A minus sign changes the answer's sign" },
        { show: "6 × 4 = 24", say: "Do the table fact without the signs" },
        { show: "−6 × 4 = −24", say: "One minus sign: the answer is negative" },
        { show: "−6 × −4 = 24", say: "Two minus signs cancel out: the answer is positive" }
      ],
      try: { question: { a: -7, b: 8 }, hint: "7 × 8 = 56. How many minus signs are there?" }
    }
  }
end
