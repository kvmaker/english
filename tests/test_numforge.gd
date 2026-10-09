extends SceneTree

const Solver := preload("res://scripts/numberforge_solver.gd")

func _initialize() -> void:
	var solver := Solver.new()
	var basic := solver.evaluate("6 + 6 + 6 + 6", [6, 6, 6, 6])
	_assert(bool(basic.ok) and bool(basic.is_target), "basic additive solution should pass")
	var division := solver.evaluate("6 / (1 - 3 / 4)", [1, 3, 4, 6])
	_assert(bool(division.ok) and bool(division.is_target), "nested division solution should pass")
	var repeated := solver.evaluate("6 + 6 + 6 + 6", [1, 3, 4, 6])
	_assert(not bool(repeated.ok), "repeated or missing cards should fail")
	var malformed := solver.evaluate("6 / (3 - 3)", [3, 3, 6, 6])
	_assert(not bool(malformed.ok), "division by zero should fail")
	var wrong := solver.evaluate("2 + 3 + 7 + 7", [2, 3, 7, 7])
	_assert(bool(wrong.ok) and not bool(wrong.is_target), "valid but non-target expression should be reported")
	print("NUMFORGE_TEST_OK")
	quit()

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)
