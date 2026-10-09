class_name NumberForgeBoard
extends RefCounted
## Exact rational-number board for the 24-point card merging interaction.

const TARGET := 24

var _cards: Array = []
var _history: Array = []
var _next_id := 1

func reset(numbers: Array) -> void:
	_cards.clear()
	_history.clear()
	_next_id = 1
	for number in numbers:
		_cards.append(_new_card(int(number), 1, str(int(number)), true))

func cards() -> Array:
	return _cards.duplicate(true)

func card_count() -> int:
	return _cards.size()

func can_undo() -> bool:
	return not _history.is_empty()

func undo() -> bool:
	if _history.is_empty():
		return false
	var snapshot: Dictionary = _history.pop_back()
	_cards = snapshot.cards.duplicate(true)
	_next_id = int(snapshot.next_id)
	return true

func merge(left_id: int, operator: String, right_id: int) -> Dictionary:
	if left_id == right_id:
		return _fail("数字 A 和数字 B 必须是两张不同的牌。")
	var left_index := _index_for(left_id)
	var right_index := _index_for(right_id)
	if left_index < 0 or right_index < 0:
		return _fail("所选数字牌已不在棋盘上。")
	if not ["+", "−", "×", "÷"].has(operator):
		return _fail("请选择一个有效的运算符。")

	var left: Dictionary = _cards[left_index]
	var right: Dictionary = _cards[right_index]
	var numerator := 0
	var denominator := 1
	match operator:
		"+":
			numerator = int(left.num) * int(right.den) + int(right.num) * int(left.den)
			denominator = int(left.den) * int(right.den)
		"−":
			numerator = int(left.num) * int(right.den) - int(right.num) * int(left.den)
			denominator = int(left.den) * int(right.den)
		"×":
			numerator = int(left.num) * int(right.num)
			denominator = int(left.den) * int(right.den)
		"÷":
			if int(right.num) == 0:
				return _fail("不能除以 0，请选择另一张数字 B。")
			numerator = int(left.num) * int(right.den)
			denominator = int(left.den) * int(right.num)

	var normalized := _normalize(numerator, denominator)
	var expression := "(%s %s %s)" % [str(left.expression), operator, str(right.expression)]
	var result := _new_card(int(normalized.num), int(normalized.den), expression, false)
	_history.append({"cards": _cards.duplicate(true), "next_id": _next_id})

	var insert_index := left_index
	if right_index < left_index:
		insert_index -= 1
	var high: int = maxi(left_index, right_index)
	var low: int = mini(left_index, right_index)
	_cards.remove_at(high)
	_cards.remove_at(low)
	_cards.insert(insert_index, result)
	return {
		"ok": true,
		"result": result.duplicate(true),
		"statement": "%s %s %s = %s" % [display_value(left), operator, display_value(right), display_value(result)]
	}

func is_target() -> bool:
	return _cards.size() == 1 and int(_cards[0].num) == TARGET * int(_cards[0].den)

func is_finished() -> bool:
	return _cards.size() == 1

func final_expression() -> String:
	return str(_cards[0].expression) if is_finished() else ""

func display_value(card: Dictionary) -> String:
	var numerator := int(card.num)
	var denominator := int(card.den)
	return str(numerator) if denominator == 1 else "%d/%d" % [numerator, denominator]

func _new_card(numerator: int, denominator: int, expression: String, initial: bool) -> Dictionary:
	var card := {
		"id": _next_id,
		"num": numerator,
		"den": denominator,
		"expression": expression,
		"initial": initial
	}
	_next_id += 1
	return card

func _index_for(card_id: int) -> int:
	for index in range(_cards.size()):
		if int(_cards[index].id) == card_id:
			return index
	return -1

func _normalize(numerator: int, denominator: int) -> Dictionary:
	if denominator < 0:
		numerator *= -1
		denominator *= -1
	if numerator == 0:
		return {"num": 0, "den": 1}
	var divisor := _gcd(absi(numerator), absi(denominator))
	return {"num": numerator / divisor, "den": denominator / divisor}

func _gcd(left: int, right: int) -> int:
	var a := left
	var b := right
	while b != 0:
		var remainder := a % b
		a = b
		b = remainder
	return max(1, a)

func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}
