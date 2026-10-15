module AttemptTestHelper
  # Answers in the shape the browser sends. Pass [a, b, given] triples
  def answers(*triples, ms: 1000)
    triples.map { |a, b, given| { a: a, b: b, given: given, ms: ms } }
  end

  def right_answers(count)
    Array.new(count) { |i| [ 2 + i % 11, 3, (2 + i % 11) * 3 ] }
  end
end
