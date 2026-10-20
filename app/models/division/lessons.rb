# A minute's tutorial for each division level, like TimesTables::Lessons. The one to try is a question as the
# topic asks it, so Division.worked writes it out and works it out
module Division::Lessons
  ALL = {
    1 => {
      steps: [
        { show: "12 ÷ 3", say: "means how many 3s make 12" },
        { show: "3, 6, 9, 12", say: "Count up in 3s until you reach 12" },
        { show: "12 ÷ 3 = 4", say: "That was four 3s, so the answer is 4" },
        { show: "4 × 3 = 12", say: "Check it with the times table" }
      ],
      try: { question: { a: 15, b: 5 }, hint: "Count up in 5s until you reach 15" }
    },
    2 => {
      steps: [
        { show: "56 ÷ 8", say: "Think of the times table the other way round" },
        { show: "? × 8 = 56", say: "What times 8 makes 56?" },
        { show: "7 × 8 = 56", say: "You know this one from your tables" },
        { show: "56 ÷ 8 = 7", say: "So 56 divided by 8 is 7" }
      ],
      try: { question: { a: 42, b: 6 }, hint: "What times 6 makes 42?" }
    },
    3 => {
      steps: [
        { show: "2400 ÷ 30", say: "Numbers with zeroes on the end" },
        { show: "24 ÷ 3 = 8", say: "Cover up the zeroes and do the table fact" },
        { show: "2400 ÷ 30", say: "Two zeroes on top, one underneath: that leaves one zero" },
        { show: "2400 ÷ 30 = 80", say: "Put the one zero back on the end of 8" }
      ],
      try: { question: { a: 3500, b: 70 }, hint: "35 ÷ 7 = 5. Two zeroes on top, one underneath" }
    },
    4 => {
      steps: [
        { show: "2.1 ÷ 0.7", say: "Decimals: move the points so you're dividing by a whole number" },
        { show: "21 ÷ 7", say: "Move both points one place: the answer stays the same" },
        { show: "21 ÷ 7 = 3", say: "Now it's a table fact" },
        { show: "2.1 ÷ 0.7 = 3", say: "So that's the answer" }
      ],
      try: { question: { a: "2.4", b: "6" }, hint: "24 ÷ 6 = 4, and 2.4 has one decimal place" }
    },
    5 => {
      steps: [
        { show: "2100 ÷ 0.7", say: "Zeroes and a decimal together" },
        { show: "21000 ÷ 7", say: "Move both points one place, so you're dividing by a whole number" },
        { show: "21 ÷ 7 = 3", say: "Cover up the zeroes and do the table fact" },
        { show: "2100 ÷ 0.7 = 3000", say: "Put the three zeroes back" }
      ],
      try: { question: { a: "1200", b: "0.4" }, hint: "Make it 12000 ÷ 4. 12 ÷ 4 = 3, then three zeroes" }
    }
  }
end
