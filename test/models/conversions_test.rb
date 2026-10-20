require "test_helper"

class ConversionsTest < ActiveSupport::TestCase
  def answer(type, a, given, level: 5)
    Conversions.clean_result({ "type" => type, "a" => a, "given" => given }, level: level)
  end

  def sample(level, count = 500, seed: 1)
    random = Random.new(seed)
    Array.new(count) { Conversions.question(Conversions.facts(level).sample(random: random), level: level, random: random) }
  end

  def units(level) = Conversions.facts(level).flat_map { _1.split(">") }.uniq.sort

  test "cm and m, then length, mass, volume, then all of them" do
    assert_equal %w[ cm m ], units(1)
    assert_equal %w[ cm km m mm ], units(2)
    assert_equal %w[ g kg mg ], units(3)
    assert_equal %w[ kl l ml ], units(4)
    assert_equal (units(2) + units(3) + units(4)).sort, units(5)
    assert_equal [ "cm>m", "m>cm" ], Conversions.facts(1)
  end

  test "to a smaller unit multiplies, to a bigger one divides, exactly" do
    assert answer("cm>m", "250", "2.5", level: 1)["correct"]
    assert answer("m>cm", "2.5", "250", level: 1)["correct"]
    assert answer("km>m", "0.35", "350", level: 2)["correct"]
    assert answer("mm>cm", "45", "4.5", level: 2)["correct"]
    assert answer("g>kg", "750", "0.75", level: 3)["correct"]
    assert answer("ml>l", "1500", "1.5", level: 4)["correct"]
    assert_not answer("cm>m", "250", "2.50", level: 1)["correct"]
    assert_equal "250 cm = 2.5 m", Conversions.label("type" => "cm>m", "a" => "250")
    assert_equal "250 cm = ? m", Conversions.worked(type: "cm>m", a: 250)[:text]
  end

  test "every generated question is one the server accepts, with tidy numbers: the smaller unit is always whole" do
    (1..5).each do |level|
      sample(level).each do |question|
        assert answer(question[:type], question[:a], question[:answer], level: level)["correct"], question.inspect
        smaller = Conversions.send(:smaller?, *question[:type].split(">")) ? question[:a] : question[:answer]
        assert_no_match(/\./, smaller, question.inspect)
      end
    end
    assert_equal [ "." ], Conversions.keys(1)
  end

  test "a level's practice asks only its own units; a daily challenge's from easier levels are accepted" do
    assert sample(3).all? { units(3).include?(_1[:type].split(">").first) }
    assert answer("cm>m", "250", "2.5", level: 3)["correct"]
    assert_raises(Attempt::Invalid) { answer("ml>l", "1500", "1.5", level: 3) }
    assert_raises(Attempt::Invalid) { answer("cm>km", "100", "0.001", level: 5) }
    assert_raises(Attempt::Invalid) { answer("cm>m", "-250", "-2.5", level: 1) }
  end

  test "every lesson's one to try works out" do
    Conversions::Lessons::ALL.each do |level, lesson|
      question = Conversions.worked(lesson[:try][:question])
      assert answer(question[:type], question[:a], question[:answer], level: level)["correct"], level
    end
  end
end
