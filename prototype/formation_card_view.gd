extends Panel

var battle
var hand_index := 0
var card_id := ""
var selected := false
var affordable := true
var name_label: Label
var cost_label: Label
var role_label: Label
var stats_label: Label
var desc_label: Label
var accent_bar: ColorRect


func setup(battle_ref, index: int, card_id_ref: String) -> void:
	battle = battle_ref
	hand_index = index
	card_id = card_id_ref
	custom_minimum_size = Vector2(156, 100)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	var def: Dictionary = battle.card_definitions[card_id]
	var role_text := _role_text(String(def["role"]))
	var accent := _role_color(String(def["role"]))
	add_theme_stylebox_override("panel", _make_style(accent, false, true))

	accent_bar = ColorRect.new()
	accent_bar.position = Vector2(0, 0)
	accent_bar.size = Vector2(4, 100)
	accent_bar.color = accent
	accent_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(accent_bar)

	name_label = Label.new()
	name_label.position = Vector2(12, 5)
	name_label.size = Vector2(112, 20)
	name_label.text = String(def["name"])
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color("#e2e8f0"))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(name_label)

	cost_label = Label.new()
	cost_label.position = Vector2(120, 5)
	cost_label.size = Vector2(30, 20)
	cost_label.text = "%d" % int(def["cost"])
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost_label.add_theme_font_size_override("font_size", 16)
	cost_label.add_theme_color_override("font_color", Color("#fbbf24"))
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cost_label)

	role_label = Label.new()
	role_label.position = Vector2(12, 26)
	role_label.size = Vector2(136, 16)
	role_label.text = role_text
	role_label.add_theme_font_size_override("font_size", 11)
	role_label.add_theme_color_override("font_color", accent)
	role_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(role_label)

	stats_label = Label.new()
	stats_label.position = Vector2(12, 43)
	stats_label.size = Vector2(136, 16)
	stats_label.text = _card_stats_text(def)
	stats_label.add_theme_font_size_override("font_size", 10)
	stats_label.add_theme_color_override("font_color", Color("#cbd5e1"))
	stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stats_label)

	desc_label = Label.new()
	desc_label.position = Vector2(12, 61)
	desc_label.size = Vector2(136, 34)
	desc_label.text = String(def["description"])
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 10)
	desc_label.add_theme_color_override("font_color", Color("#94a3b8"))
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(desc_label)

	tooltip_text = "%s · %s\n%s\n费用 %d\n%s" % [
		String(def["name"]), role_text, _card_stats_text(def), int(def["cost"]), String(def["description"])
	]


func _card_stats_text(def: Dictionary) -> String:
	var role := String(def["role"])
	if role == "resource":
		return "体力 +%d / %.0fs" % [
			int(def.get("resource", 0)),
			float(def.get("resource_interval", 4.0))
		]
	if role == "tactic":
		return "同路相邻友军 +%d" % int(def.get("aura", 0))
	return "生命 %d · 伤%d · %.1fs" % [
		int(def["hp"]),
		int(def.get("damage", 0)),
		float(def.get("interval", 1.0))
	]


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


func _role_color(role: String) -> Color:
	match role:
		"attack":
			return Color("#fb923c")
		"disrupt":
			return Color("#facc15")
		"defense":
			return Color("#60a5fa")
		"resource":
			return Color("#34d399")
		"tactic":
			return Color("#c084fc")
	return Color("#94a3b8")


func _make_style(accent: Color, is_selected: bool, is_affordable: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0b1a2a") if is_affordable else Color("#131a22")
	style.border_color = Color("#fbbf24") if is_selected else accent
	style.set_border_width_all(3 if is_selected else 1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 4
	return style


func set_state(is_selected: bool, is_affordable: bool) -> void:
	selected = is_selected
	affordable = is_affordable
	var accent := _role_color(String(battle.card_definitions[card_id]["role"]))
	add_theme_stylebox_override("panel", _make_style(accent, selected, affordable))
	modulate = Color.WHITE if affordable else Color(0.55, 0.55, 0.55, 1.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		battle.select_card(hand_index)


func _get_drag_data(_at_position: Vector2):
	if battle == null:
		return null
	if battle.phase != "deploy" and battle.phase != "battle":
		return null
	var def: Dictionary = battle.card_definitions[card_id]
	var preview := Panel.new()
	preview.size = Vector2(150, 58)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.07, 0.12, 0.96)
	style.border_color = _role_color(String(def["role"]))
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	preview.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.position = Vector2(10, 8)
	label.size = Vector2(130, 20)
	label.text = "%s  ·  %d 体力" % [String(def["name"]), int(def["cost"])]
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color("#e2e8f0"))
	preview.add_child(label)
	var sub := Label.new()
	sub.position = Vector2(10, 30)
	sub.size = Vector2(130, 18)
	sub.text = _card_stats_text(def)
	sub.add_theme_font_size_override("font_size", 10)
	sub.add_theme_color_override("font_color", Color("#94a3b8"))
	preview.add_child(sub)
	set_drag_preview(preview)
	return {"type": "formation_card", "card_id": card_id, "hand_index": hand_index}
