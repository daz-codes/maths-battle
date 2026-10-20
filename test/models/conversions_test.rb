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

  test "cm and m, then length, mass, volume, then imperial lengths" do
    assert_equal %w[ cm m ], units(1)
    assert_equal %w[ cm km m mm ], units(2)
    assert_equal %w[ g kg mg ], units(3)
    assert_equal %w[ kl l ml ], units(4)
    assert_equal %w[ cm in km mi ], units(5)
    assert_equal "Imperial lengths", Conversions.level(5)[:name]
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
    (1..4).each do |level|
      sample(level).each do |question|
        assert answer(question[:type], question[:a], question[:answer], level: level)["correct"], question.inspect
        smaller = Conversions.send(:smaller?, *question[:type].split(">")) ? question[:a] : question[:answer]
        assert_no_match(/\./, smaller, question.inspect)
      end
    end
    assert_equal [ "." ], Conversions.keys(1)
  end

  test "imperial lengths, roughly: an inch is 2.5 cm and 5 miles is 8 km, both ways, always whole" do
    assert answer("in>cm", "12", "30")["correct"]
    assert answer("cm>in", "25", "10")["correct"]
    assert answer("mi>km", "15", "24")["correct"]
    assert answer("km>mi", "40", "25")["correct"]
    assert_equal "12 inches ≈ ? cm", Conversions.worked(type: "in>cm", a: 12)[:text]
    assert_equal "40 km ≈ 25 miles", Conversions.label("type" => "km>mi", "a" => "40")
    assert_equal "cm → inches", Conversions.group_label("cm>in")

    sample(5).each do |question|
      assert answer(question[:type], question[:a], question[:answer])["correct"], question.inspect
      assert_match(/\A\d+\z/, question[:answer], question.inspect)
      assert_includes question[:text], "≈"
    end
    assert_equal Conversions::IMPERIAL.keys.sort, sample(5).map { _1[:type] }.uniq.sort
  end

  test "imperial amounts that wouldn't come out whole aren't ones the game asks" do
    assert_raises(Attempt::Invalid) { answer("km>mi", "3", "1.875") }
    assert_raises(Attempt::Invalid) { answer("in>cm", "2.5", "6.25") }
    assert_raises(Attempt::Invalid) { answer("mi>km", "15", "24", level: 4) }
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
