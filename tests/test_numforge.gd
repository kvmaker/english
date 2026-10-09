extends SceneTree

const Board := preload("res://scripts/numberforge_board.gd")

func _initialize() -> void:
	_test_basic_merges()
	_test_fraction_route()
	_test_invalid_division_and_undo()
	print("NUMFORGE_TEST_OK")
	quit()

func _test_basic_merges() -> void:
	var board := Board.new()
	board.reset([6, 6, 6, 6])
	var first_cards := board.cards()
	var first := board.merge(int(first_cards[0].id), "+", int(first_cards[1].id))
	_assert(bool(first.ok), "first merge should succeed")
	var second_cards := board.cards()
	var second := board.merge(int(second_cards[0].id), "+", int(second_cards[1].id))
	_assert(bool(second.ok), "second merge should succeed")
	var final_cards := board.cards()
	var final := board.merge(int(final_cards[0].id), "+", int(final_cards[1].id))
	_assert(bool(final.ok) and board.is_target(), "three 6-card merges should reach 24")

func _test_fraction_route() -> void:
	var board := Board.new()
	board.reset([1, 3, 4, 6])
	var cards := board.cards()
	var fraction := board.merge(int(cards[1].id), "÷", int(cards[2].id))
	_assert(bool(fraction.ok), "3 ÷ 4 should create a fraction card")
	cards = board.cards()
	_assert(board.display_value(cards[1]) == "3/4", "fraction must retain exact representation")
	var quarter := board.merge(int(cards[0].id), "−", int(cards[1].id))
	_assert(bool(quarter.ok), "1 − 3/4 should merge")
	cards = board.cards()
	var final := board.merge(int(cards[1].id), "÷", int(cards[0].id))
	_assert(bool(final.ok) and board.is_target(), "6 ÷ (1 − 3/4) should reach 24")

func _test_invalid_division_and_undo() -> void:
	var board := Board.new()
	board.reset([3, 3, 6, 6])
	var cards := board.cards()
	var zero := board.merge(int(cards[0].id), "−", int(cards[1].id))
	_assert(bool(zero.ok), "3 − 3 should create zero")
	cards = board.cards()
	var invalid := board.merge(int(cards[1].id), "÷", int(cards[0].id))
	_assert(not bool(invalid.ok), "division by a zero card must fail")
	_assert(board.undo(), "undo should restore the previous card pair")
	_assert(board.cards().size() == 4, "undo should restore four cards")

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)
