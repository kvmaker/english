extends Control
## Complete, desktop-first 24-point game UI with progressive levels and non-modal hints.

const Solver := preload("res://scripts/numberforge_solver.gd")
const SAVE_PATH := "user://numforge_progress.json"
const TARGET := 24.0
const LEVELS := [
	{"numbers": [6, 6, 6, 6], "title": "热身相加", "tier": "初试", "solution": "6 + 6 + 6 + 6", "hints": ["这一关不需要括号，试着让四张牌都直接参与。", "四个 6 的总和刚好是目标值。"]},
	{"numbers": [2, 3, 7, 7], "title": "成对组合", "tier": "初试", "solution": "(2 × 7) + (3 + 7)", "hints": ["可以先把其中一个 7 与较小数字相乘。", "先做 2 × 7，再把余下两张牌相加。"]},
	{"numbers": [5, 5, 5, 1], "title": "小数点之外", "tier": "策略", "solution": "5 × (5 − 1 ÷ 5)", "hints": ["先用 1 和一个 5 造出一个很小的分数。", "把 1 ÷ 5 从另一个 5 中减去，结果再乘剩下的 5。"]},
	{"numbers": [2, 4, 6, 8], "title": "差值作分母", "tier": "策略", "solution": "(6 × 8) ÷ (4 − 2)", "hints": ["6 和 8 可以组成一个很大的乘积。", "用 4 − 2 做分母，就能把 48 变为 24。"]},
	{"numbers": [1, 3, 4, 6], "title": "括号转折", "tier": "策略", "solution": "6 ÷ (1 − 3 ÷ 4)", "hints": ["目标可以由 6 除以一个小于 1 的数得到。", "先计算 3 ÷ 4，再用 1 减去它。"]},
	{"numbers": [3, 3, 7, 7], "title": "分数增幅", "tier": "进阶", "solution": "7 × (3 + 3 ÷ 7)", "hints": ["先让一个 7 作为外层乘数。", "括号里是 3 加上 3 ÷ 7。"]},
	{"numbers": [2, 5, 7, 9], "title": "乘积回调", "tier": "进阶", "solution": "(5 × 7) − (2 + 9)", "hints": ["5 和 7 的乘积比 24 大一点。", "从 35 中减去剩下两张牌的和。"]},
	{"numbers": [3, 4, 7, 11], "title": "反转分数", "tier": "进阶", "solution": "(7 + 11) ÷ (3 ÷ 4)", "hints": ["两个较大的数相加可以得到 18。", "用 3 ÷ 4 作分母，18 会变成 24。"]},
	{"numbers": [3, 8, 10, 11], "title": "差值倍增", "tier": "大师", "solution": "(3 × 8) × (11 − 10)", "hints": ["先看 3 和 8，它们已经很接近目标。", "11 − 10 恰好是 1，可保持 3 × 8 的结果。"]},
	{"numbers": [5, 6, 7, 8], "title": "双括号", "tier": "大师", "solution": "(5 + 7) × (8 − 6)", "hints": ["把两组数字分别做加法与减法。", "12 乘以 2 正好是 24。"]},
	{"numbers": [2, 8, 9, 11], "title": "整除拼接", "tier": "大师", "solution": "(8 ÷ 2) + (9 + 11)", "hints": ["8 ÷ 2 是一个整齐的小数字。", "用 4 加上其余两张牌的和即可。"]},
	{"numbers": [1, 5, 7, 11], "title": "终局配对", "tier": "终局", "solution": "(1 + 5) + (7 + 11)", "hints": ["最终关仍可从成对组合的视角思考。", "先得到 6 与 18，再让它们相加。"]}
]

var solver := Solver.new()
var level_index := 0
var unlocked_level := 0
var hints_revealed := 0
var number_buttons: Array[Button] = []
var expression_edit: LineEdit
var level_picker: OptionButton
var level_tag: Label
var progress_label: Label
var progress_bar: ProgressBar
var challenge_label: Label
var objective_label: Label
var numbers_caption: Label
var status_label: Label
var hint_panel: PanelContainer
var hint_label: Label
var hint_button: Button
var success_panel: PanelContainer
var success_title: Label
var success_detail: Label
var next_button: Button
var unlocked_label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_load_progress()
	_build_interface()
	_load_level(0)

func _build_interface() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("091426")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 54)
	margin.add_theme_constant_override("margin_right", 54)
	margin.add_theme_constant_override("margin_top", 38)
	margin.add_theme_constant_override("margin_bottom", 34)
	add_child(margin)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 16)
	margin.add_child(page)

	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 54)
	page.add_child(header)
	var brand := Label.new()
	brand.text = "数算挑战"
	brand.add_theme_color_override("font_color", Color("F7F4E9"))
	brand.add_theme_font_size_override("font_size", 34)
	brand.add_theme_font_size_override("font_outline_size", 8)
	brand.add_theme_color_override("font_outline_color", Color("0F2740"))
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(brand)
	level_tag = _tag("第 1 关 · 初试", Color("1BC7AA"))
	header.add_child(level_tag)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(12, 1)
	header.add_child(spacer)
	level_picker = OptionButton.new()
	level_picker.custom_minimum_size = Vector2(138, 42)
	level_picker.focus_mode = Control.FOCUS_NONE
	level_picker.add_theme_font_size_override("font_size", 16)
	level_picker.add_theme_color_override("font_color", Color("F7F4E9"))
	level_picker.add_theme_stylebox_override("normal", _style(Color("152741"), 12, Color("2B5B7C"), 1))
	level_picker.item_selected.connect(_on_level_selected)
	header.add_child(level_picker)

	progress_bar = ProgressBar.new()
	progress_bar.max_value = LEVELS.size()
	progress_bar.show_percentage = false
	progress_bar.custom_minimum_size = Vector2(0, 10)
	progress_bar.add_theme_stylebox_override("background", _style(Color("15233A"), 7))
	progress_bar.add_theme_stylebox_override("fill", _style(Color("1BC7AA"), 7))
	page.add_child(progress_bar)
	progress_label = Label.new()
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	progress_label.add_theme_color_override("font_color", Color("90A9C3"))
	progress_label.add_theme_font_size_override("font_size", 14)
	page.add_child(progress_label)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	page.add_child(body)

	var mission_panel := _panel()
	mission_panel.custom_minimum_size = Vector2(365, 0)
	body.add_child(mission_panel)
	var mission := _panel_content(mission_panel)
	mission.add_theme_constant_override("separation", 16)
	var eyebrow := Label.new()
	eyebrow.text = "本关目标"
	eyebrow.add_theme_color_override("font_color", Color("8AA7C7"))
	eyebrow.add_theme_font_size_override("font_size", 16)
	mission.add_child(eyebrow)
	objective_label = Label.new()
	objective_label.text = "凑出 24"
	objective_label.add_theme_color_override("font_color", Color("FFD579"))
	objective_label.add_theme_font_size_override("font_size", 50)
	mission.add_child(objective_label)
	var rule := Label.new()
	rule.text = "用完全部四张数字牌\n允许 +、−、×、÷ 与括号"
	rule.add_theme_color_override("font_color", Color("D3E2F0"))
	rule.add_theme_font_size_override("font_size", 17)
	rule.add_theme_constant_override("line_spacing", 5)
	mission.add_child(rule)
	var rule_line := HSeparator.new()
	rule_line.add_theme_stylebox_override("separator", _style(Color("27435E"), 1))
	mission.add_child(rule_line)
	challenge_label = Label.new()
	challenge_label.add_theme_color_override("font_color", Color("A9C2D9"))
	challenge_label.add_theme_font_size_override("font_size", 18)
	challenge_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mission.add_child(challenge_label)
	unlocked_label = Label.new()
	unlocked_label.add_theme_color_override("font_color", Color("7F9CB9"))
	unlocked_label.add_theme_font_size_override("font_size", 15)
	mission.add_child(unlocked_label)
	var grow := Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mission.add_child(grow)
	hint_button = _button("查看提示  ·  不影响当前表达式", Color("224C65"), Color("41D8BD"))
	hint_button.pressed.connect(_on_hint_pressed)
	mission.add_child(hint_button)
	hint_panel = PanelContainer.new()
	hint_panel.visible = false
	hint_panel.add_theme_stylebox_override("panel", _style(Color("0D2433"), 14, Color("2C897E"), 1))
	mission.add_child(hint_panel)
	var hint_margin := MarginContainer.new()
	hint_margin.add_theme_constant_override("margin_left", 14)
	hint_margin.add_theme_constant_override("margin_right", 14)
	hint_margin.add_theme_constant_override("margin_top", 12)
	hint_margin.add_theme_constant_override("margin_bottom", 12)
	hint_panel.add_child(hint_margin)
	hint_label = Label.new()
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.add_theme_color_override("font_color", Color("C8F7E9"))
	hint_label.add_theme_font_size_override("font_size", 15)
	hint_margin.add_child(hint_label)

	var play_panel := _panel()
	play_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(play_panel)
	var play := _panel_content(play_panel)
	play.add_theme_constant_override("separation", 15)
	numbers_caption = Label.new()
	numbers_caption.text = "数字牌 · 点击加入表达式"
	numbers_caption.add_theme_color_override("font_color", Color("DCEAF5"))
	numbers_caption.add_theme_font_size_override("font_size", 19)
	play.add_child(numbers_caption)
	var card_grid := GridContainer.new()
	card_grid.columns = 4
	card_grid.add_theme_constant_override("h_separation", 12)
	card_grid.add_theme_constant_override("v_separation", 12)
	play.add_child(card_grid)
	for index in range(4):
		var card := _button("—", Color("153B55"), Color("73E4D0"))
		card.custom_minimum_size = Vector2(0, 104)
		card.add_theme_font_size_override("font_size", 40)
		card.pressed.connect(_on_number_pressed.bind(index))
		card_grid.add_child(card)
		number_buttons.append(card)

	var expression_caption := Label.new()
	expression_caption.text = "组合表达式"
	expression_caption.add_theme_color_override("font_color", Color("DCEAF5"))
	expression_caption.add_theme_font_size_override("font_size", 19)
	play.add_child(expression_caption)
	expression_edit = LineEdit.new()
	expression_edit.placeholder_text = "例如：(8 ÷ 2) + (9 + 11)"
	expression_edit.custom_minimum_size = Vector2(0, 62)
	expression_edit.add_theme_font_size_override("font_size", 24)
	expression_edit.add_theme_color_override("font_color", Color("F8F4E9"))
	expression_edit.add_theme_color_override("font_placeholder_color", Color("66859F"))
	expression_edit.add_theme_stylebox_override("normal", _style(Color("0C1E34"), 14, Color("335873"), 2))
	expression_edit.add_theme_stylebox_override("focus", _style(Color("0D243B"), 14, Color("1BC7AA"), 2))
	expression_edit.text_changed.connect(_on_expression_changed)
	expression_edit.text_submitted.connect(_on_check_pressed)
	play.add_child(expression_edit)

	var operations := GridContainer.new()
	operations.columns = 7
	operations.add_theme_constant_override("h_separation", 9)
	operations.add_theme_constant_override("v_separation", 9)
	play.add_child(operations)
	for entry in [["+", " + "], ["−", " − "], ["×", " × "], ["÷", " ÷ "], ["(", "("], [")", ")"], ["退格", "back"]]:
		var op_button := _button(entry[0], Color("1A314B"), Color("B8D5E8"))
		op_button.custom_minimum_size = Vector2(0, 48)
		op_button.add_theme_font_size_override("font_size", 17 if entry[1] == "back" else 23)
		op_button.pressed.connect(_on_operation_pressed.bind(entry[1]))
		operations.add_child(op_button)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 10)
	play.add_child(action_row)
	var check_button := _button("校验答案", Color("E36F52"), Color("FFE9D2"))
	check_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	check_button.custom_minimum_size = Vector2(0, 52)
	check_button.add_theme_font_size_override("font_size", 19)
	check_button.pressed.connect(_on_check_pressed)
	action_row.add_child(check_button)
	var clear_button := _button("清空", Color("21354E"), Color("D5E5F4"))
	clear_button.custom_minimum_size = Vector2(108, 52)
	clear_button.pressed.connect(_clear_expression)
	action_row.add_child(clear_button)

	status_label = Label.new()
	status_label.custom_minimum_size = Vector2(0, 32)
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	play.add_child(status_label)
	success_panel = PanelContainer.new()
	success_panel.visible = false
	success_panel.add_theme_stylebox_override("panel", _style(Color("123E3A"), 16, Color("31D7AD"), 2))
	play.add_child(success_panel)
	var success_margin := MarginContainer.new()
	success_margin.add_theme_constant_override("margin_left", 18)
	success_margin.add_theme_constant_override("margin_right", 18)
	success_margin.add_theme_constant_override("margin_top", 16)
	success_margin.add_theme_constant_override("margin_bottom", 16)
	success_panel.add_child(success_margin)
	var success_box := VBoxContainer.new()
	success_box.add_theme_constant_override("separation", 8)
	success_margin.add_child(success_box)
	success_title = Label.new()
	success_title.add_theme_color_override("font_color", Color("AAFFE6"))
	success_title.add_theme_font_size_override("font_size", 27)
	success_box.add_child(success_title)
	success_detail = Label.new()
	success_detail.add_theme_color_override("font_color", Color("D5F7EC"))
	success_detail.add_theme_font_size_override("font_size", 16)
	success_box.add_child(success_detail)
	next_button = _button("下一关 →", Color("1BC7AA"), Color("062019"))
	next_button.custom_minimum_size = Vector2(0, 46)
	next_button.pressed.connect(_on_next_pressed)
	success_box.add_child(next_button)

	var footer := Label.new()
	footer.text = "提示只展示思路，不会清空表达式或改变关卡进度。"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_color_override("font_color", Color("6E89A4"))
	footer.add_theme_font_size_override("font_size", 14)
	page.add_child(footer)

func _load_level(next_index: int) -> void:
	level_index = clampi(next_index, 0, LEVELS.size() - 1)
	hints_revealed = 0
	var level = LEVELS[level_index]
	_clear_expression()
	hint_panel.visible = false
	success_panel.visible = false
	level_tag.text = "第 %d 关 · %s" % [level_index + 1, level.tier]
	challenge_label.text = "难度 %s\n%s" % [level.tier, level.title]
	progress_bar.value = level_index + 1
	progress_label.text = "关卡进度  %d / %d" % [level_index + 1, LEVELS.size()]
	unlocked_label.text = "已解锁 %d / %d 关" % [unlocked_level + 1, LEVELS.size()]
	numbers_caption.text = "数字牌 · %s" % level.title
	for index in range(number_buttons.size()):
		number_buttons[index].text = str(level.numbers[index])
		_sync_number_cards()
	_rebuild_level_picker()
	status_label.text = "组合一个等于 24 的表达式。"
	status_label.add_theme_color_override("font_color", Color("89A8C3"))

func _rebuild_level_picker() -> void:
	level_picker.clear()
	for i in range(unlocked_level + 1):
		level_picker.add_item("第 %d 关" % (i + 1))
	level_picker.select(level_index)

func _on_number_pressed(card_index: int) -> void:
	if number_buttons[card_index].disabled:
		return
	_append_text(str(LEVELS[level_index].numbers[card_index]))

func _on_operation_pressed(token: String) -> void:
	if token == "back":
		if not expression_edit.text.is_empty():
			expression_edit.text = expression_edit.text.left(expression_edit.text.length() - 1)
			expression_edit.caret_column = expression_edit.text.length()
			_sync_number_cards()
		return
	_append_text(token)

func _append_text(token: String) -> void:
	expression_edit.text += token
	expression_edit.caret_column = expression_edit.text.length()
	expression_edit.grab_focus()
	_sync_number_cards()

func _clear_expression() -> void:
	if expression_edit == null:
		return
	expression_edit.text = ""
	expression_edit.caret_column = 0
	_sync_number_cards()
	if status_label != null:
		status_label.text = "组合一个等于 24 的表达式。"
		status_label.add_theme_color_override("font_color", Color("89A8C3"))

func _on_expression_changed(_new_text: String) -> void:
	_sync_number_cards()

func _sync_number_cards() -> void:
	if expression_edit == null or level_index >= LEVELS.size():
		return
	var used_counts := {}
	var text := expression_edit.text
	var current := ""
	for i in range(text.length() + 1):
		var char := text.substr(i, 1) if i < text.length() else " "
		if "0123456789".find(char) >= 0:
			current += char
		elif not current.is_empty():
			var parsed := int(current)
			used_counts[parsed] = int(used_counts.get(parsed, 0)) + 1
			current = ""
	var seen := {}
	for index in range(number_buttons.size()):
		var number := int(LEVELS[level_index].numbers[index])
		var occurrence := int(seen.get(number, 0)) + 1
		seen[number] = occurrence
		var used := int(used_counts.get(number, 0)) >= occurrence
		number_buttons[index].disabled = used
		number_buttons[index].modulate = Color(0.45, 0.55, 0.67, 0.55) if used else Color.WHITE

func _on_check_pressed(_submitted: String = "") -> void:
	var result := solver.evaluate(expression_edit.text, LEVELS[level_index].numbers)
	if not result.ok:
		_show_status("还差一点：%s" % result.error, Color("FFAF91"))
		return
	var value := float(result.value)
	if bool(result.is_target):
		_show_success(value)
	else:
		_show_status("当前结果为 %s，与 24 相差 %s。继续调整试试。" % [_format_number(value), _format_number(absf(TARGET - value))], Color("FFD579"))

func _show_success(value: float) -> void:
	_show_status("表达式正确！", Color("80F0D0"))
	success_panel.visible = true
	success_title.text = "答对了，24 达成！"
	success_detail.text = "你的计算结果是 %s。%s" % [_format_number(value), "下一关已解锁。" if level_index < LEVELS.size() - 1 else "你已完成全部挑战！"]
	if level_index < LEVELS.size() - 1:
		unlocked_level = max(unlocked_level, level_index + 1)
		_save_progress()
		next_button.text = "下一关 →" if level_index < LEVELS.size() - 1 else "重新挑战第一关"
		next_button.grab_focus()

func _on_next_pressed() -> void:
	if level_index >= LEVELS.size() - 1:
		_load_level(0)
	else:
		_load_level(level_index + 1)

func _on_hint_pressed() -> void:
	var hints: Array = LEVELS[level_index].hints
	hints_revealed = min(hints_revealed + 1, hints.size())
	hint_panel.visible = true
	if hints_revealed < hints.size():
		hint_label.text = "提示 %d/%d\n%s\n\n再次点击“查看提示”可继续。" % [hints_revealed, hints.size(), hints[hints_revealed - 1]]
	else:
		hint_label.text = "完整思路\n%s\n\n参考表达式：%s" % [hints[hints.size() - 1], LEVELS[level_index].solution]
	hint_button.text = "查看下一条提示" if hints_revealed < hints.size() else "提示已全部展开"

func _on_level_selected(selected: int) -> void:
	if selected <= unlocked_level:
		_load_level(selected)

func _show_status(message: String, color: Color) -> void:
	status_label.text = message
	status_label.add_theme_color_override("font_color", color)

func _load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if parsed is Dictionary:
		unlocked_level = clampi(int(parsed.get("unlocked_level", 0)), 0, LEVELS.size() - 1)

func _save_progress() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"unlocked_level": unlocked_level}))

func _format_number(value: float) -> String:
	return str(int(round(value))) if is_equal_approx(value, round(value)) else "%.2f" % value

func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color("10243C"), 20, Color("244765"), 1))
	return panel

func _panel_content(panel: PanelContainer) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	margin.add_child(box)
	return box

func _tag(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(132, 38)
	label.add_theme_color_override("font_color", Color("061E22"))
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_stylebox_override("normal", _style(color, 19))
	return label

func _button(text: String, base: Color, text_color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_stylebox_override("normal", _style(base, 13))
	button.add_theme_stylebox_override("hover", _style(base.lightened(0.12), 13))
	button.add_theme_stylebox_override("pressed", _style(base.darkened(0.10), 13))
	button.add_theme_stylebox_override("disabled", _style(Color("17273A"), 13))
	return button

func _style(background: Color, radius: int = 14, border: Color = Color.TRANSPARENT, border_width: int = 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_right = radius
	box.corner_radius_bottom_left = radius
	box.border_color = border
	box.border_width_left = border_width
	box.border_width_right = border_width
	box.border_width_top = border_width
	box.border_width_bottom = border_width
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box
