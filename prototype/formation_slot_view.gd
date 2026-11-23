extends Panel

var battle
var side := "player"
var lane := 0
var row := 0
var unit = null
var name_label: Label
var status_label: Label
var hp_bar: Panel
var hp_fill: Panel
var hp_label: Label
var stats_label: Label
var highlight := false
var placeable := false
var bar_width := 92.0


func setup(battle_ref, side_ref: String, lane_ref: int, row_ref: int) -> void:
	battle = battle_ref
	side = side_ref
	lane = lane_ref
	row = row_ref
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	add_theme_stylebox_override("panel", _make_style(Color("#223246"), false))
	var width: float = size.x
	if width < 80.0:
		width = 104.0
	bar_width = width - 12.0

	name_label = Label.new()
	name_label.position = Vector2(6, 8)
	name_label.size = Vector2(width - 36.0, 16)
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color("#3f5568"))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(name_label)

	status_label = Label.new()
	status_label.position = Vector2(width - 30.0, 8)
	status_label.size = Vector2(24, 16)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.add_theme_font_size_override("font_size", 9)
	status_label.add_theme_color_override("font_color", Color("#fbbf24"))
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(status_label)

	hp_bar = Panel.new()
	hp_bar.position = Vector2(6, 30)
	hp_bar.size = Vector2(bar_width, 6)
	hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color("#1f2937")
	bar_bg.set_corner_radius_all(3)
	hp_bar.add_theme_stylebox_override("panel", bar_bg)
	add_child(hp_bar)

	hp_fill = Panel.new()
	hp_fill.position = Vector2.ZERO
	hp_fill.size = Vector2(bar_width, 6)
	hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_fill.add_theme_stylebox_override("panel", _make_fill(1.0))
	hp_bar.add_child(hp_fill)

	hp_label = Label.new()
	hp_label.position = Vector2(6, 38)
	hp_label.size = Vector2(bar_width, 12)
	hp_label.add_theme_font_size_override("font_size", 9)
	hp_label.add_theme_color_override("font_color", Color("#cbd5e1"))
	hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hp_label)

	stats_label = Label.new()
	stats_label.position = Vector2(6, 56)
	stats_label.size = Vector2(bar_width, 14)
	stats_label.add_theme_font_size_override("font_size", 9)
	stats_label.add_theme_color_override("font_color", Color("#94a3b8"))
	stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stats_label)


func _make_style(border: Color, has_unit: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if side == "player":
		style.bg_color = Color("#0b1a2a") if has_unit else Color("#08131e")
	else:
		style.bg_color = Color("#1a0f12") if has_unit else Color("#120c0f")
	style.border_color = Color("#fbbf24") if highlight else (Color("#34d399") if placeable else border)
	style.set_border_width_all(2 if (highlight or placeable) else 1)
	style.set_corner_radius_all(5)
	return style


func set_highlight(on: bool) -> void:
	highlight = on


func set_placeable(on: bool) -> void:
	placeable = on


func refresh(unit_ref) -> void:
	unit = unit_ref
	if unit == null:
		name_label.text = "可放置" if placeable else "空位"
		name_label.add_theme_color_override("font_color", Color("#6ee7b7") if placeable else Color("#3f5568"))
		status_label.text = ""
		hp_bar.visible = false
		hp_label.text = ""
		stats_label.text = ""
		tooltip_text = "空阵位"
		add_theme_stylebox_override("panel", _make_style(Color("#223246"), false))
		modulate = Color.WHITE
		return

	name_label.text = String(unit.display_name)
	name_label.add_theme_color_override("font_color", Color("#fecaca") if side == "enemy" else Color("#e2e8f0"))
	status_label.text = unit.status_text()
	hp_bar.visible = true
	var ratio := clampf(float(unit.hp) / float(max(1, int(unit.max_hp))), 0.0, 1.0)
	hp_fill.size = Vector2(bar_width * ratio, 6.0)
	hp_fill.add_theme_stylebox_override("panel", _make_fill(ratio))
	hp_label.text = "生命 %d / %d" % [max(0, int(unit.hp)), int(unit.max_hp)]
	stats_label.text = unit.stats_text()
	add_theme_stylebox_override("panel", _make_style(unit.role_color(), true))
	modulate = Color.WHITE

	var tip := "%s · %s\n生命 %d / %d\n%s" % [
		String(unit.display_name), _role_text(String(unit.role)), int(unit.hp), int(unit.max_hp), unit.stats_text()
	]
	if unit.taunt:
		tip += "\n嘲讽：同路敌人优先攻击此单位"
	if unit.ignore_taunt:
		tip += "\n破防：无视嘲讽，优先攻击最后排"
	if unit.charge_interval > 0.0:
		tip += "\n蓄力：每 %.0f 秒，下次攻击 3 倍" % unit.charge_interval
	if unit.suppress_player_regen:
		tip += "\n压制：存活时玩家体力恢复减半"
	if unit.regen_amount > 0:
		tip += "\n再生：每秒恢复 %d 点生命" % unit.regen_amount
	if unit.back_row_bonus > 0:
		tip += "\n后排：位于后排时伤害 +%d" % unit.back_row_bonus
	if unit.healthy_bonus > 0:
		tip += "\n攻坚：目标生命高于 60%% 时伤害 +%d" % unit.healthy_bonus
	if unit.taunt_front_bonus > 0:
		tip += "\n掩护：同路前排有嘲讽友军时伤害 +%d" % unit.taunt_front_bonus
	if side == "player" and String(battle.phase) == "deploy":
		tip += "\n拖动此单位可调整位置"
	tooltip_text = tip


func _role_text(role: String) -> String:
	match role:
		"attack":
			return "攻击"
		"disrupt":
			return "牵制"
		"defense":
			return "防御"
		"resource":
			return "资源"
		"tactic":
			return "战术"
	return role


func _make_fill(ratio: float) -> StyleBoxFlat:
	var fill := StyleBoxFlat.new()
	if ratio <= 0.3:
		fill.bg_color = Color("#ef4444")
	elif ratio <= 0.6:
		fill.bg_color = Color("#f59e0b")
	else:
		fill.bg_color = Color("#34d399")
	fill.set_corner_radius_all(2)
	return fill


func _can_drop_data(_at_position: Vector2, data) -> bool:
	if side != "player" or not (data is Dictionary):
		return false
	var kind := String(data.get("type", ""))
	return kind == "formation_card" or kind == "formation_unit_move"


func _drop_data(_at_position: Vector2, data) -> void:
	if side != "player" or not (data is Dictionary):
		return
	var kind := String(data.get("type", ""))
	if kind == "formation_card":
		battle.try_deploy(String(data.get("card_id", "")), int(data.get("hand_index", -1)), lane, row)
	elif kind == "formation_unit_move":
		battle.try_move_unit(int(data.get("lane", -1)), int(data.get("row", -1)), lane, row)


func _get_drag_data(_at_position: Vector2):
	if battle == null or unit == null or side != "player":
		return null
	if String(battle.phase) != "deploy":
		return null
	var role_color: Color = unit.role_color()
	var preview := Panel.new()
	preview.size = Vector2(120, 40)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.07, 0.12, 0.96)
	style.border_color = role_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	preview.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.position = Vector2(10, 8)
	label.size = Vector2(100, 20)
	label.text = String(unit.display_name)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color("#e2e8f0"))
	preview.add_child(label)
	set_drag_preview(preview)
	return {"type": "formation_unit_move", "lane": lane, "row": row}


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		battle.on_slot_clicked(side, lane, row)
