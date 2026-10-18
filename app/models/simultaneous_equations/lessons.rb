# A minute's tutorial for each simultaneous equations level, like TimesTables::Lessons. The one to try is a
# pair as the topic asks it, so SimultaneousEquations.worked lines it up in columns and solves it for x
module SimultaneousEquations::Lessons
  ALL = {
    1 => {
      steps: [
        { show: [ "3x + 5y = 11", "2x + 5y = 9" ], say: "Two equations, and both have 5y" },
        { show: "x = 2", say: "Take the bottom one from the top: the 5y's cancel, leaving x = 2" },
        { show: "2 × 2 + 5y = 9", say: "Put x = 2 back into one of them" },
        { show: [ "5y = 5", "y = 1" ], say: "Take away 4, then divide by 5" }
      ],
      try: { question: { type: "subtract", a: 4, b: 3, c: 18, d: 3, e: 3, f: 15 }, hint: "Both have 3y: take the bottom one from the top" }
    },
    2 => {
      steps: [
        { show: [ "5x + 2y = 16", "2x + 2y = 10" ], say: "Both have 2y" },
        { show: "3x = 6", say: "Subtract: the 2y's cancel, leaving 3x" },
        { show: "x = 2", say: "Divide by 3" },
        { show: [ "2 × 2 + 2y = 10", "y = 3" ], say: "Put x = 2 back in to find y" }
      ],
      try: { question: { type: "subtract and divide", a: 4, b: 1, c: 9, d: 2, e: 1, f: 5 }, hint: "Subtract to get 2x, then divide by 2" }
    },
    3 => {
      steps: [
        { show: [ "2x + 3y = 13", "x − 3y = −7" ], say: "One has +3y and the other −3y" },
        { show: "3x = 6", say: "Add them: +3y and −3y cancel out" },
        { show: "x = 2", say: "Divide by 3" },
        { show: [ "2 × 2 + 3y = 13", "y = 3" ], say: "Put x = 2 back in to find y" }
      ],
      try: { question: { type: "add", a: 2, b: 1, c: 7, d: 1, e: -1, f: 2 }, hint: "Add them: +y and −y cancel out" }
    },
    4 => {
      steps: [
        { show: [ "3x − 2y = 5", "x − 2y = −1" ], say: "Both have −2y, so subtract" },
        { show: [ "2x = 6", "x = 3" ], say: "Take care with the signs: 5 − −1 = 6" },
        { show: "3 − 2y = −1", say: "Put x = 3 into the second one" },
        { show: "y = 2", say: "−2y = −4, so y = 2" }
      ],
      try: { question: { type: "add", a: 1, b: 2, c: 8, d: 2, e: -2, f: 4 }, hint: "+2y and −2y: add them to cancel the y's" }
    },
    5 => {
      steps: [
        { show: [ "x + y = 5", "3x + 2y = 12" ], say: "The y terms don't match yet" },
        { show: "2x + 2y = 10", say: "Double the first equation, everything in it" },
        { show: "x = 2", say: "Take that from the second: 3x − 2x = x, and 12 − 10 = 2" },
        { show: [ "2 + y = 5", "y = 3" ], say: "Put x = 2 back in to find y" }
      ],
      try: { question: { type: "multiply", a: 1, b: 1, c: 4, d: 3, e: 2, f: 10 }, hint: "Double the first equation, then take it from the second" }
    }
  }
end
