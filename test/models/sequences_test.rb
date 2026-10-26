require "test_helper"

class SequencesTest < ActiveSupport::TestCase
  def next_of(type, a:, b: 0, c: 0) = Sequences.worked(type: type, a: a, b: b, c: c)

  test "each kind of sequence, five terms shown and the next to find" do
    assert_equal [ "3, 7, 11, 15, 19, …", "23" ], next_of("add", a: 3, b: 4).values_at(:text, :answer)
    assert_equal [ "50, 43, 36, 29, 22, …", "15" ], next_of("subtract", a: 50, b: 7).values_at(:text, :answer)
    assert_equal [ "2, 5, 10, 17, 26, …", "37" ], next_of("square", a: 1, b: 1).values_at(:text, :answer)
    assert_equal [ "4, 6, 10, 16, 24, …", "34" ], next_of("quadratic", a: 4, b: 2, c: 2).values_at(:text, :answer)
    assert_equal [ "3, 6, 12, 24, 48, …", "96" ], next_of("double", a: 3).values_at(:text, :answer)
    assert_equal [ "2, 6, 18, 54, 162, …", "486" ], next_of("times", a: 2, b: 3).values_at(:text, :answer)
    assert_equal [ "192, 96, 48, 24, 12, …", "6" ], next_of("halve", a: 192).values_at(:text, :answer)
    assert_equal [ "2, 5, 7, 12, 19, …", "31" ], next_of("fibonacci", a: 2, b: 5).values_at(:text, :answer)
    assert_equal [ "4, 9, 11, 16, 18, …", "23" ], next_of("alternate", a: 4, b: 5, c: 2).values_at(:text, :answer)
    assert_equal "3, 7, 11, 15, 19, 23", Sequences.label({ "type" => "add", "a" => 3, "b" => 4, "c" => 0 })
  end

  test "every question has one answer, whichever kind of sequence it might be, and whole, positive terms" do
    random = Random.new(1)
    Sequences::TYPES.each_key do |type|
      200.times do
        question = Sequences.question(type, random: random)
        terms = Sequences.terms(question)
        assert terms.all? { _1.is_a?(Integer) && _1.positive? }, question[:text]
        assert Sequences.send(:next_terms, terms.first(Sequences.shown(question))).all?(terms.last), "#{question[:text]} has more than one answer"
        assert_operator terms.last, :<=, Sequences::MOST
      end
    end
  end

  test "a question that two kinds of sequence would continue differently is never asked, or accepted" do
    assert_equal [ 243 ], Sequences.send(:next_terms, [ 1, 3, 9, 27, 81 ]), "only multiplying fits"
    assert Sequences.send(:one_answer?, [ 4, 7, 10, 13, 16 ], 19), "linear and two equal steps agree"
    assert_not Sequences.send(:one_answer?, [ 1, 2, 4, 8, 16 ], 31), "what doubling doesn't give"
    assert_raises(Attempt::Invalid, "two equal steps are just linear: a level 5 question must take turns") do
      Sequences.clean_result({ "type" => "alternate", "a" => 4, "b" => 3, "c" => 3, "given" => "19" }, level: 5)
    end
  end

  test "two steps show 5 to 7 terms, so the next step isn't always the first one" do
    six = Sequences.worked(type: "alternate", a: 4, b: 5, c: 2, n: 6)
    assert_equal [ "4, 9, 11, 16, 18, 23, …", "25" ], six.values_at(:text, :answer), "after six, it's the second step"
    assert_equal "23", Sequences.worked(type: "alternate", a: 4, b: 5, c: 2)[:answer], "five, as a lesson's, is the first step again"

    random = Random.new(2)
    shown = Array.new(60) { Sequences.question("alternate", random: random)[:n] }.tally
    assert_equal [ 5, 6, 7 ], shown.keys.sort
    assert_operator shown[6], :>, shown[5], "half the time the next is the second step"
    assert_raises(Attempt::Invalid, "only two steps vary") { Sequences.clean_result({ "type" => "add", "a" => 3, "b" => 4, "c" => 0, "n" => 6, "given" => "27" }) }
    assert_raises(Attempt::Invalid) { Sequences.clean_result({ "type" => "alternate", "a" => 4, "b" => 5, "c" => 2, "n" => 9, "given" => "1" }, level: 5) }
  end

  test "a level asks only its own kinds, mixed practice the ones before too, and answers are only digits" do
    assert_equal %w[ add subtract ], Sequences.facts(1)
    assert_equal %w[ alternate ], Sequences.facts(5)
    assert_equal Sequences::TYPES.keys, Sequences.facts_through(5)
    assert_raises(Attempt::Invalid) { Sequences.clean_result({ "type" => "fibonacci", "a" => 2, "b" => 5, "c" => 0, "given" => "31" }, level: 3) }
    assert Sequences.clean_result({ "type" => "fibonacci", "a" => 2, "b" => 5, "c" => 0, "given" => "31" }, level: 4)["correct"]
    assert_empty Sequences.keys(5)
  end
end
