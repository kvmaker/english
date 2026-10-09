extends Control
## 1024-inspired 24-point game: choose number A, operator, then number B to merge cards.

const Board := preload("res://scripts/numberforge_board.gd")
const SAVE_PATH := "user://numforge_progress.json"
const LEVELS := [
	{"numbers": [6, 6, 6, 6], "title": "热身相加", "tier": "初试", "solution": "6 + 6 + 6 + 6", "hints": ["从任意两张 6 开始相加。", "把第一次得到的 12，再与其余两张 6 依次相加。"]},
	{"numbers": [2, 3, 7, 7], "title": "成对组合", "tier": "初试", "solution": "(2 × 7) + (3 + 7)", "hints": ["可以先让一个 7 与较小数字相乘。", "先做 2 × 7，再合并 3 + 7，最后把两个结果相加。"]},
	{"numbers": [5, 5, 5, 1], "title": "小数点之外", "tier": "策略", "solution": "5 × (5 − 1 ÷ 5)", "hints": ["先用 1 和一个 5 造出一张分数牌。", "依次合并 1 ÷ 5、5 − 结果、5 × 结果。"]},
	{"numbers": [2, 4, 6, 8], "title": "差值作分母", "tier": "策略", "solution": "(6 × 8) ÷ (4 − 2)", "hints": ["6 和 8 可以先合出一个大数字。", "再合并 4 − 2，最后让两个结果相除。"]},
	{"numbers": [1, 3, 4, 6], "title": "括号转折", "tier": "策略", "solution": "6 ÷ (1 − 3 ÷ 4)", "hints": ["先从 3 和 4 开始，得到一张分数牌。", "依次合并 3 ÷ 4、1 − 结果、6 ÷ 结果。"]},
	{"numbers": [3, 3, 7, 7], "title": "分数增幅", "tier": "进阶", "solution": "7 × (3 + 3 ÷ 7)", "hints": ["先让一个 3 除以一个 7。", "再用另一个 3 加上分数，最后乘剩下的 7。"]},
	{"numbers": [2, 5, 7, 9], "title": "乘积回调", "tier": "进阶", "solution": "(5 × 7) − (2 + 9)", "hints": ["5 和 7 的乘积比 24 大一点。", "把 2 和 9 合成 11，再从 35 中减去它。"]},
	{"numbers": [3, 4, 7, 11], "title": "反转分数", "tier": "进阶", "solution": "(7 + 11) ÷ (3 ÷ 4)", "hints": ["先将两个较大的数合并成 18。", "3 ÷ 4 是关键分数；再让 18 除以它。"]},
	{"numbers": [3, 8, 10, 11], "title": "差值倍增", "tier": "大师", "solution": "(3 × 8) × (11 − 10)", "hints": ["先看 3 和 8，它们已经能合成目标值。", "11 − 10 得到 1，再和 24 相乘。"]},
	{"numbers": [5, 6, 7, 8], "title": "双括号", "tier": "大师", "solution": "(5 + 7) × (8 − 6)", "hints": ["两组数字可分别合成 12 与 2。", "把 5 + 7 与 8 − 6 合并后再相乘。"]},
	{"numbers": [2, 8, 9, 11], "title": "整除拼接", "tier": "大师", "solution": "(8 ÷ 2) + (9 + 11)", "hints": ["先让 8 ÷ 2 得到一个整齐的数字。", "再合并 9 + 11，最后将 4 与 20 相加。"]},
	{"numbers": [1, 5, 7, 11], "title": "终局配对", "tier": "终局", "solution": "(1 + 5) + (7 + 11)", "hints": ["这关可从两两配对的视角思考。", "先合并 1 + 5 与 7 + 11，再把 6 和 18 相加。"]}
]

var board := Board.new()
var level_index := 0
var unlocked_level := 0
var hints_revealed := 0
var selected_card_id := -1
var selected_operator := ""
var level_picker: OptionButton
var level_tag: Label
var progress_label: Label
var progress_bar: ProgressBar
var challenge_label: Label
var unlocked_label: Label
var deck_caption: Label
var deck_grid: GridContainer
var state_label: Label
var trail_label: Label
var status_label: Label
var hint_panel: PanelContainer
var hint_label: Label
var hint_button: Button
var undo_button: Button
var reset_button: Button
var success_panel: PanelContainer
var success_title: Label
var success_detail: Label
var next_button: Button
var operator_buttons := {}

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
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 30)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 15)
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
	mission_panel.custom_minimum_size = Vector2(350, 0)
	body.add_child(mission_panel)
	var mission := _panel_content(mission_panel)
	mission.add_theme_constant_override("separation", 15)
	var eyebrow := Label.new()
	eyebrow.text = "本关目标"
	eyebrow.add_theme_color_override("font_color", Color("8AA7C7"))
	eyebrow.add_theme_font_size_override("font_size", 16)
	mission.add_child(eyebrow)
	var objective := Label.new()
	objective.text = "合并出 24"
	objective.add_theme_color_override("font_color", Color("FFD579"))
	objective.add_theme_font_size_override("font_size", 45)
	mission.add_child(objective)
	var rules := Label.new()
	rules.text = "每次合并两张牌：\n第一步：选择数字 A\n第二步：选择运算符\n第三步：选择数字 B\n\n合并后的结果会成为一张新牌。"
	rules.add_theme_color_override("font_color", Color("D3E2F0"))
	rules.add_theme_font_size_override("font_size", 16)
	rules.add_theme_constant_override("line_spacing", 5)
	mission.add_child(rules)
	var divider := HSeparator.new()
	divider.add_theme_stylebox_override("separator", _style(Color("27435E"), 1))
	mission.add_child(divider)
	challenge_label = Label.new()
	challenge_label.add_theme_color_override("font_color", Color("A9C2D9"))
	challenge_label.add_theme_font_size_override("font_size", 17)
	challenge_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mission.add_child(challenge_label)
	unlocked_label = Label.new()
	unlocked_label.add_theme_color_override("font_color", Color("7F9CB9"))
	unlocked_label.add_theme_font_size_override("font_size", 15)
	mission.add_child(unlocked_label)
	var grow := Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mission.add_child(grow)
	hint_button = _button("查看提示  ·  不中断合并", Color("224C65"), Color("41D8BD"))
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
	deck_caption = Label.new()
	deck_caption.add_theme_color_override("font_color", Color("DCEAF5"))
	deck_caption.add_theme_font_size_override("font_size", 20)
	play.add_child(deck_caption)
	state_label = Label.new()
	state_label.custom_minimum_size = Vector2(0, 34)
	state_label.add_theme_color_override("font_color", Color("8DEAD5"))
	state_label.add_theme_font_size_override("font_size", 17)
	play.add_child(state_label)
	deck_grid = GridContainer.new()
	deck_grid.columns = 4
	deck_grid.add_theme_constant_override("h_separation", 12)
	deck_grid.add_theme_constant_override("v_separation", 12)
	play.add_child(deck_grid)

	var op_caption := Label.new()
	op_caption.text = "选择运算符"
	op_caption.add_theme_color_override("font_color", Color("DCEAF5"))
	op_caption.add_theme_font_size_override("font_size", 18)
	play.add_child(op_caption)
	var operations := GridContainer.new()
	operations.columns = 4
	operations.add_theme_constant_override("h_separation", 10)
	operations.add_theme_constant_override("v_separation", 10)
	play.add_child(operations)
	for operator in ["+", "−", "×", "÷"]:
		var op_button := _button(operator, Color("1A314B"), Color("B8D5E8"))
		op_button.custom_minimum_size = Vector2(0, 58)
		op_button.add_theme_font_size_override("font_size", 30)
		op_button.pressed.connect(_on_operator_pressed.bind(operator))
		operations.add_child(op_button)
		operator_buttons[operator] = op_button

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 10)
	play.add_child(action_row)
	undo_button = _button("撤销上一步", Color("1D4761"), Color("C7ECF4"))
	undo_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	undo_button.custom_minimum_size = Vector2(0, 50)
	undo_button.pressed.connect(_on_undo_pressed)
	action_row.add_child(undo_button)
	reset_button = _button("重置本关", Color("313F57"), Color("E0EAF5"))
	reset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_button.custom_minimum_size = Vector2(0, 50)
	reset_button.pressed.connect(_reset_board)
	action_row.add_child(reset_button)

	trail_label = Label.new()
	trail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	trail_label.add_theme_color_override("font_color", Color("A6BDD2"))
	trail_label.add_theme_font_size_override("font_size", 14)
	trail_label.custom_minimum_size = Vector2(0, 40)
	play.add_child(trail_label)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.custom_minimum_size = Vector2(0, 30)
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
	success_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	success_detail.add_theme_color_override("font_color", Color("D5F7EC"))
	success_detail.add_theme_font_size_override("font_size", 15)
	success_box.add_child(success_detail)
	next_button = _button("下一关 →", Color("1BC7AA"), Color("062019"))
	next_button.custom_minimum_size = Vector2(0, 46)
	next_button.pressed.connect(_on_next_pressed)
	success_box.add_child(next_button)

	var footer := Label.new()
	footer.text = "提示只展示思路；“撤销合并”可回退一步；分数牌会以精确形式保留。"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_color_override("font_color", Color("6E89A4"))
	footer.add_theme_font_size_override("font_size", 14)
	page.add_child(footer)

func _load_level(next_index: int) -> void:
	level_index = clampi(next_index, 0, LEVELS.size() - 1)
	hints_revealed = 0
	selected_card_id = -1
	selected_operator = ""
	board.reset(LEVELS[level_index].numbers)
	hint_panel.visible = false
	success_panel.visible = false
	hint_button.text = "查看提示  ·  不中断合并"
	level_tag.text = "第 %d 关 · %s" % [level_index + 1, LEVELS[level_index].tier]
	challenge_label.text = "难度 %s\n%s" % [LEVELS[level_index].tier, LEVELS[level_index].title]
	progress_bar.value = level_index + 1
	progress_label.text = "关卡进度  %d / %d" % [level_index + 1, LEVELS.size()]
	unlocked_label.text = "已解锁 %d / %d 关" % [unlocked_level + 1, LEVELS.size()]
	_rebuild_level_picker()
	_render_board()
	_show_status("从任意一张数字牌开始，选择数字 A。", Color("89A8C3"))

func _rebuild_level_picker() -> void:
	level_picker.clear()
	for index in range(unlocked_level + 1):
		level_picker.add_item("第 %d 关" % (index + 1))
	level_picker.select(level_index)

func _render_board() -> void:
	for child in deck_grid.get_children():
		child.queue_free()
	var cards := board.cards()
	deck_grid.columns = max(1, min(4, cards.size()))
	deck_caption.text = "数字牌组 · 剩余 %d 张" % cards.size()
	for card in cards:
		var card_id := int(card.id)
		var selected := card_id == selected_card_id
		var color := Color("1B776F") if selected else (Color("1B526D") if bool(card.initial) else Color("35477A"))
		var card_button := _button(board.display_value(card), color, Color("F7F4E9"))
		card_button.custom_minimum_size = Vector2(126, 124)
		card_button.add_theme_font_size_override("font_size", 38 if board.display_value(card).length() <= 3 else 28)
		card_button.tooltip_text = str(card.expression)
		card_button.pressed.connect(_on_card_pressed.bind(card_id))
		deck_grid.add_child(card_button)
	var selected_text := "未选择" if selected_card_id < 0 else _selected_card_value()
	var operator_text := "未选择" if selected_operator.is_empty() else selected_operator
	state_label.text = "数字 A：%s    运算符：%s    数字 B：等待选择" % [selected_text, operator_text]
	trail_label.text = _trail_text(cards)
	undo_button.disabled = not board.can_undo()
	for operator in operator_buttons:
		var button: Button = operator_buttons[operator]
		var active: bool = str(operator) == selected_operator
		button.add_theme_stylebox_override("normal", _style(Color("1BC7AA") if active else Color("1A314B"), 13))
		button.add_theme_color_override("font_color", Color("062019") if active else Color("B8D5E8"))

func _trail_text(cards: Array) -> String:
	var expressions: Array[String] = []
	for card in cards:
		if not bool(card.initial):
			expressions.append("%s = %s" % [str(card.expression), board.display_value(card)])
	return "当前合并结果：" if expressions.is_empty() else "当前合并结果：\n" + "   ·   ".join(expressions)

func _on_card_pressed(card_id: int) -> void:
	if board.is_finished():
		_show_status("本轮已结束。可重置本关，或进入下一关。", Color("FFD579"))
		return
	if selected_card_id < 0:
		selected_card_id = card_id
		_show_status("已选数字 A：%s。现在选择运算符。" % _selected_card_value(), Color("8DEAD5"))
		_render_board()
		return
	if selected_operator.is_empty():
		selected_card_id = card_id
		_show_status("数字 A 已切换为 %s。请选择运算符。" % _selected_card_value(), Color("8DEAD5"))
		_render_board()
		return
	if card_id == selected_card_id:
		_show_status("数字 B 需要选择另一张牌。", Color("FFAF91"))
		return
	var merged := board.merge(selected_card_id, selected_operator, card_id)
	if not bool(merged.ok):
		_show_status("无法合并：%s" % merged.error, Color("FFAF91"))
		return
	var statement := str(merged.statement)
	selected_card_id = -1
	selected_operator = ""
	_render_board()
	if board.is_target():
		_show_success(statement)
	elif board.is_finished():
		_show_status("最后一张牌是 %s，不是 24。点击“重置本关”再试一次，或撤销上一步。" % board.display_value(board.cards()[0]), Color("FFD579"))
	else:
		_show_status("%s。继续选择下一组数字牌。" % statement, Color("8DEAD5"))

func _on_operator_pressed(operator: String) -> void:
	if board.is_finished():
		_show_status("本轮已结束。可重置本关，或进入下一关。", Color("FFD579"))
		return
	if selected_card_id < 0:
		_show_status("先选择一张数字牌作为数字 A。", Color("FFAF91"))
		return
	selected_operator = operator
	_render_board()
	_show_status("已选 %s %s … 现在选择数字 B。" % [_selected_card_value(), operator], Color("8DEAD5"))

func _on_undo_pressed() -> void:
	if not board.undo():
		_show_status("还没有可撤销的合并。", Color("89A8C3"))
		return
	selected_card_id = -1
	selected_operator = ""
	success_panel.visible = false
	_render_board()
	_show_status("已撤销上一次合并。", Color("8DEAD5"))

func _reset_board() -> void:
	selected_card_id = -1
	selected_operator = ""
	board.reset(LEVELS[level_index].numbers)
	success_panel.visible = false
	_render_board()
	_show_status("本关已重置。从数字 A 开始重新组合。", Color("89A8C3"))

func _on_hint_pressed() -> void:
	var hints: Array = LEVELS[level_index].hints
	hints_revealed = min(hints_revealed + 1, hints.size())
	hint_panel.visible = true
	if hints_revealed < hints.size():
		hint_label.text = "提示 %d/%d\n%s\n\n再次点击“查看提示”可继续。" % [hints_revealed, hints.size(), hints[hints_revealed - 1]]
		hint_button.text = "查看下一条提示"
	else:
		hint_label.text = "完整合并路线\n%s\n\n参考表达式：%s" % [hints[hints.size() - 1], LEVELS[level_index].solution]
		hint_button.text = "提示已全部展开"

func _show_success(statement: String) -> void:
	unlocked_level = max(unlocked_level, min(level_index + 1, LEVELS.size() - 1))
	_save_progress()
	_render_board()
	_show_status("%s。24 达成！" % statement, Color("80F0D0"))
	success_panel.visible = true
	success_title.text = "答对了，24 达成！"
	success_detail.text = "最终合并：%s\n完整算式：%s" % [statement, board.final_expression()]
	next_button.text = "下一关 →" if level_index < LEVELS.size() - 1 else "重新挑战第一关"
	next_button.grab_focus()

func _on_next_pressed() -> void:
	_load_level(0 if level_index >= LEVELS.size() - 1 else level_index + 1)

func _on_level_selected(selected: int) -> void:
	if selected <= unlocked_level:
		_load_level(selected)

func _selected_card_value() -> String:
	for card in board.cards():
		if int(card.id) == selected_card_id:
			return board.display_value(card)
	return "—"

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
