# A minute's tutorial for each metric conversions level, like TimesTables::Lessons. The one to try is a question
# as the topic asks it, so Conversions.worked writes it out and works it out
module Conversions::Lessons
  ALL = {
    1 => {
      steps: [
        { show: "1 m = 100 cm", say: "There are 100 centimetres in a metre" },
        { show: "3 m = 300 cm", say: "Metres to centimetres: multiply by 100" },
        { show: "250 cm = 2.5 m", say: "Centimetres to metres: divide by 100" },
        { show: "2.5 × 100 = 250", say: "Check it by going back the other way" }
      ],
      try: { question: { type: "cm>m", a: 450 }, hint: "Divide 450 by 100" }
    },
    2 => {
      steps: [
        { show: "10 mm = 1 cm", say: "10 millimetres in a centimetre" },
        { show: "1000 m = 1 km", say: "1000 metres in a kilometre" },
        { show: "3.5 km = 3500 m", say: "To a smaller unit, multiply: the number gets bigger" },
        { show: "45 mm = 4.5 cm", say: "To a bigger unit, divide: the number gets smaller" }
      ],
      try: { question: { type: "km>m", a: "2.4" }, hint: "Kilometres to metres: multiply by 1000" }
    },
    3 => {
      steps: [
        { show: "1000 g = 1 kg", say: "1000 grams in a kilogram" },
        { show: "1000 mg = 1 g", say: "and 1000 milligrams in a gram" },
        { show: "1.2 kg = 1200 g", say: "Kilograms to grams: multiply by 1000" },
        { show: "750 g = 0.75 kg", say: "Grams to kilograms: divide by 1000" }
      ],
      try: { question: { type: "g>kg", a: 3500 }, hint: "Divide 3500 by 1000" }
    },
    4 => {
      steps: [
        { show: "1000 ml = 1 l", say: "1000 millilitres in a litre" },
        { show: "1000 l = 1 kl", say: "and 1000 litres in a kilolitre" },
        { show: "750 ml = 0.75 l", say: "Millilitres to litres: divide by 1000" },
        { show: "2.5 l = 2500 ml", say: "Litres to millilitres: multiply by 1000" }
      ],
      try: { question: { type: "l>ml", a: "1.5" }, hint: "Multiply 1.5 by 1000" }
    },
    5 => {
      steps: [
        { show: "1 inch ≈ 2.5 cm", say: "Inches are an old, imperial unit: one is about two and a half centimetres" },
        { show: "12 inches ≈ 30 cm", say: "Inches to cm: multiply by 2.5. 12 × 2 = 24, and half of 12 more is 30" },
        { show: "5 miles ≈ 8 km", say: "Miles are longer: 5 miles is about 8 kilometres" },
        { show: "15 miles ≈ 24 km", say: "15 miles is three lots of 5 miles, so it's three lots of 8 km" }
      ],
      try: { question: { type: "in>cm", a: 8 }, hint: "8 × 2.5: 8 × 2 = 16, and half of 8 more" }
    }
  }
end
