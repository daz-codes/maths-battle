# A minute's tutorial for each adding and subtracting level, like TimesTables::Lessons. The one to try is a
# question as the topic asks it, so Addition.worked writes it out and works it out
module Addition::Lessons
  ALL = {
    1 => {
      steps: [
        { show: "8 + 7", say: "Make a ten first" },
        { show: "8 + 2 = 10", say: "8 needs 2 more to make 10" },
        { show: "10 + 5 = 15", say: "7 is 2 and 5, so add the 5 that's left" },
        { show: "15 − 7 = 8", say: "Taking away undoes it: 15 − 7 takes you back to 8" }
      ],
      try: { question: { type: "add", a: 9, b: 6 }, hint: "9 needs 1 more to make 10" }
    },
    2 => {
      steps: [
        { show: "47 + 38", say: "Split the second number into tens and ones" },
        { show: "47 + 30 = 77", say: "Add the tens first" },
        { show: "77 + 8 = 85", say: "Then the ones" },
        { show: "82 − 46 = 36", say: "Taking away works the same: 82 − 40 = 42, then 42 − 6 = 36" }
      ],
      try: { question: { type: "add", a: 56, b: 27 }, hint: "56 + 20, then add 7" }
    },
    3 => {
      steps: [
        { show: "347 + 285", say: "Hundreds, then tens, then ones" },
        { show: "347 + 200 = 547", say: "Add the hundreds" },
        { show: "547 + 80 = 627", say: "Then the tens" },
        { show: "627 + 5 = 632", say: "Then the ones: 347 + 285 = 632" }
      ],
      try: { question: { type: "subtract", a: 612, b: 248 }, hint: "612 − 200 = 412. Then take away 40, then 8" }
    },
    4 => {
      steps: [
        { show: "4700 − 2800", say: "Round numbers with zeroes on the end" },
        { show: "47 − 28 = 19", say: "Cover up the zeroes: it's a two digit question" },
        { show: "4700 − 2800 = 1900", say: "Put the zeroes back on the end" },
        { show: "470 + 380 = 850", say: "Adding works the same: 47 + 38 = 85, and one zero" }
      ],
      try: { question: { type: "add", a: 560, b: 270 }, hint: "56 + 27, then put the zero back" }
    },
    5 => {
      steps: [
        { show: "2.3 − 0.32", say: "Decimals: line up the decimal points" },
        { show: "2.30 − 0.32", say: "Give both two decimal places, so 2.3 is 2.30" },
        { show: "230 − 32 = 198", say: "Now take away as if there were no points" },
        { show: "2.3 − 0.32 = 1.98", say: "Put the point back, two places from the end" }
      ],
      try: { question: { type: "add", a: "4.7", b: "3.8" }, hint: "47 + 38 = 85, with one decimal place" }
    }
  }
end
