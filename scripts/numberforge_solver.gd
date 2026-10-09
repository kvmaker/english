class_name NumberForgeSolver
extends RefCounted
## Safe parser and validator for a four-number 24-point expression.

var _tokens: Array[String] = []
var _cursor := 0
var _used_numbers: Array[int] = []
var _parse_error := ""

func evaluate(raw_expression: String, required_numbers: Array) -> Dictionary:
	_tokens.clear()
	_used_numbers.clear()
	_cursor = 0
	_parse_error = ""
	var source := raw_expression.strip_edges().replace("×", "*").replace("÷", "/").replace("（", "(").replace("）", ")")
	if source.is_empty():
		return _fail("先组合一个表达式，再来校验。")
	var token_result := _tokenize(source)
	if not token_result.ok:
		return _fail(token_result.error)
	var parsed := _parse_expression()
	if not parsed.ok:
		return _fail(_parse_error if not _parse_error.is_empty() else "表达式格式不完整。")
	if _cursor != _tokens.size():
		return _fail("这里似乎多了一个运算符或括号。")
	var numbers_result := _validate_number_use(required_numbers)
	if not numbers_result.ok:
		return numbers_result
	return {
		"ok": true,
		"value": float(parsed.value),
		"is_target": is_equal_approx(float(parsed.value), 24.0),
		"used_numbers": _used_numbers.duplicate()
	}

func _tokenize(source: String) -> Dictionary:
	var digits := "0123456789"
	var i := 0
	while i < source.length():
		var ch := source.substr(i, 1)
		if ch == " " or ch == "\t" or ch == "\n":
			i += 1
			continue
		if digits.find(ch) >= 0:
			var start := i
			while i < source.length() and digits.find(source.substr(i, 1)) >= 0:
				i += 1
			_tokens.append(source.substr(start, i - start))
			continue
		if "+-*/()".find(ch) >= 0:
			_tokens.append(ch)
			i += 1
			continue
		return {"ok": false, "error": "只可使用数字、+、−、×、÷ 和括号。"}
	if _tokens.is_empty():
		return {"ok": false, "error": "表达式不能为空。"}
	return {"ok": true}

func _parse_expression() -> Dictionary:
	var left := _parse_term()
	if not left.ok:
		return left
	while _peek() == "+" or _peek() == "-":
		var op := _advance()
		var right := _parse_term()
		if not right.ok:
			return right
		left.value = float(left.value) + float(right.value) if op == "+" else float(left.value) - float(right.value)
	return left

func _parse_term() -> Dictionary:
	var left := _parse_factor()
	if not left.ok:
		return left
	while _peek() == "*" or _peek() == "/":
		var op := _advance()
		var right := _parse_factor()
		if not right.ok:
			return right
		if op == "/":
			if absf(float(right.value)) < 0.000001:
				_parse_error = "不能除以 0。"
				return {"ok": false}
			left.value = float(left.value) / float(right.value)
		else:
			left.value = float(left.value) * float(right.value)
	return left

func _parse_factor() -> Dictionary:
	var token := _peek()
	if token.is_empty():
		_parse_error = "表达式还没有结束。"
		return {"ok": false}
	if token == "(":
		_advance()
		var inside := _parse_expression()
		if not inside.ok:
			return inside
		if _peek() != ")":
			_parse_error = "括号没有正确闭合。"
			return {"ok": false}
		_advance()
		return inside
	if token.is_valid_int():
		_advance()
		_used_numbers.append(int(token))
		return {"ok": true, "value": float(token)}
	_parse_error = "请在运算符之间放入数字。"
	return {"ok": false}

func _validate_number_use(required_numbers: Array) -> Dictionary:
	var counts := {}
	for number in required_numbers:
		counts[int(number)] = int(counts.get(int(number), 0)) + 1
	for number in _used_numbers:
		if not counts.has(number) or int(counts[number]) <= 0:
			return _fail("数字 %d 不在本关牌组中，或被重复使用了。" % number)
		counts[number] = int(counts[number]) - 1
	if _used_numbers.size() != required_numbers.size():
		return _fail("四张数字牌都要恰好使用一次。")
	for number in counts:
		if int(counts[number]) != 0:
			return _fail("四张数字牌都要恰好使用一次。")
	return {"ok": true}

func _peek() -> String:
	return _tokens[_cursor] if _cursor < _tokens.size() else ""

func _advance() -> String:
	var token := _peek()
	_cursor += 1
	return token

func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}
