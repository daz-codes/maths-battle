# A minute's tutorial for each functions level, like TimesTables::Lessons. The one to try is a question as the
# topic asks it, so Functions.worked writes it out (a function on each line) and works it out
module Functions::Lessons
  ALL = {
    1 => {
      steps: [
        { show: "f(x) = 2x + 3", say: "A function is a rule: put a number in, and get one out" },
        { show: "f(4) = 2 × 4 + 3", say: "f(4) means put 4 in place of x" },
        { show: "f(4) = 11", say: "Then work it out: 8 + 3 = 11" }
      ],
      try: { question: { type: "ax-b", a: 3, b: 1, n: 5 }, hint: "Put 5 in place of x: 3 × 5 − 1" }
    },
    2 => {
      steps: [
        { show: "f(x) = 3x + 10", say: "Now the number going in can be negative" },
        { show: "f(−4) = 3 × −4 + 10", say: "Put −4 in place of x" },
        { show: "−12 + 10 = −2", say: "3 × −4 is −12, then add 10" },
        { show: "f(x) = x/2 + 5, so f(−6) = 2", say: "x/2 means divide by 2: −3 + 5 = 2" }
      ],
      try: { question: { type: "x-a", a: 7, n: 3 }, hint: "Put 3 in place of x: 3 − 7 goes below zero" }
    },
    3 => {
      steps: [
        { show: "f(x) = x² − 5", say: "x² means x × x" },
        { show: "f(−3) = (−3)² − 5", say: "Put −3 in place of x" },
        { show: "(−3)² = 9", say: "A negative times a negative is positive" },
        { show: "f(−3) = 9 − 5 = 4", say: "Then take away 5" }
      ],
      try: { question: { type: "x^2+a", a: 4, n: -2 }, hint: "(−2)² is −2 × −2, which is positive" }
    },
    4 => {
      steps: [
        { show: [ "f(x) = 2x + 1", "g(x) = x − 3" ], say: "Two functions, and one goes inside the other" },
        { show: "f(g(5))", say: "Work from the inside out: g first" },
        { show: "g(5) = 5 − 3 = 2", say: "g turns 5 into 2" },
        { show: "f(2) = 2 × 2 + 1 = 5", say: "Then put that into f: f(g(5)) = 5" }
      ],
      try: { question: { type: "g(f(x))", a: 2, b: 1, c: 1, d: -3, n: 4 }, hint: "Inside out: work out f(4) first, then put that into g" }
    },
    5 => {
      steps: [
        { show: "f(x) = 3x − 2", say: "f⁻¹ undoes f: it takes an answer back to where it started" },
        { show: "f⁻¹(10)", say: "Which number does f turn into 10?" },
        { show: "10 + 2 = 12, 12 ÷ 3 = 4", say: "Undo the steps backwards: add the 2, then divide by 3" },
        { show: "f⁻¹(10) = 4", say: "Check it: f(4) = 3 × 4 − 2 = 10 ✓" }
      ],
      try: { question: { type: "inv:ax+b", a: 2, b: 3, n: 11 }, hint: "Backwards: take away the 3, then divide by 2" }
    }
  }
end
