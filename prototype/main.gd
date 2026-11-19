extends Node3D

const PLAYER_SPEED := 5.0
const INTERACTION_DISTANCE := 3.2
const BATTLE_CARD_TYPE_LIMIT := 1

var player: CharacterBody3D
var camera: Camera3D
var nearby_npc: Node3D
var nearby_gate: Node3D
var dialogue_panel: Panel
var dialogue_title: Label
var dialogue_text: Label
var interaction_hint: Label
var economy_hud: Panel
var economy_text: Label
var deck_view_button: Button
var deck_view_panel: Panel
var deck_view_title: Label
var deck_view_summary: Label
var deck_view_rows: VBoxContainer
var codex_button: Button
var codex_panel: Panel
var codex_title: Label
var codex_summary: Label
var codex_rows: VBoxContainer
var shop_panel: Panel
var shop_title: Label
var shop_balance: Label
var shop_feedback: Label
var shop_rows: VBoxContainer
var battle_panel: Panel
var battle_status: Label
var battle_intent: Label
var battle_feedback: Label
var battle_turn_label: Label
var battle_deck_label: Label
var battle_player_hp_bar: ProgressBar
var battle_opponent_hp_bar: ProgressBar
var battle_player_hp_text: Label
var battle_opponent_hp_text: Label
var battle_cards_container: HBoxContainer
var battle_card_buttons: Array[Button] = []
var battle_card_widgets: Array[Dictionary] = []
var battle_pending_draw_indices: Array[int] = []
var battle_shuffle_pending := false
var battle_animation_layer: Control
var battle_end_button: Button
var battle_opponent: Node3D
var dialogue_index := 0
var dialogue_lines: Array[String] = []
var battle_player_hp := 30
var battle_opponent_hp := 30
var battle_block := 0
var battle_turn := 1
var battle_weakens_opponent := false
var battle_finished := false
var battle_won := false
var battle_hand: Array[Dictionary] = []
var battle_deck: Array[String] = []
var battle_discard: Array[String] = []
var battle_type_uses: Dictionary = {}
var battle_feedback_text := ""
var player_deck: Array[String] = ["forehand", "backhand", "guard", "curve", "forehand", "backhand", "guard", "curve", "forehand", "backhand"]

var battle_card_definitions := {
	"forehand": {"name": "正手击打", "type": "damage", "value": 6, "description": "造成 6 点伤害"},
	"backhand": {"name": "反手快攻", "type": "damage", "value": 4, "description": "造成 4 点伤害"},
	"guard": {"name": "架拍格挡", "type": "block", "value": 7, "description": "抵挡本回合 7 点伤害"},
	"curve": {"name": "旋球扰乱", "type": "disrupt", "value": 3, "description": "造成 3 点伤害，并削弱对手本回合攻击"}
}
var money := 120
var inventory := {
	"energy_drink": 1,
	"data_chip": 0,
	"repair_kit": 1
}

var shop_items := [
	{"id": "energy_drink", "name": "能量饮料", "buy": 20, "sell": 10, "description": "恢复状态的便携饮品"},
	{"id": "data_chip", "name": "数据芯片", "buy": 35, "sell": 18, "description": "存有城市接口资料"},
	{"id": "repair_kit", "name": "维修工具包", "buy": 28, "sell": 14, "description": "常见设备维修材料"}
]

var npcs := [
	{
		"name": "林遥",
		"role": "城市接口工程师",
		"position": Vector3(3.5, 1.0, -3.0),
		"color": Color("#4cc9f0"),
		"lines": [
			"你也是第一次来这片测试区？",
			"这里的公共现实层还没有完全同步，看到不同的东西很正常。",
			"先和另一位访客聊聊，也许她知道入口在哪里。"
		]
	},
	{
		"name": "周岚",
		"role": "独立记录员",
		"position": Vector3(-3.5, 1.0, -5.0),
		"color": Color("#f72585"),
		"type": "dialogue",
		"lines": [
			"我在记录这里的居民如何使用自己的现实层。",
			"林遥说的入口，可能只对拥有工程权限的人开放。",
			"如果你愿意帮忙，我可以把这段记录交给你。"
		]
	},
	{
		"name": "阿铎",
		"role": "流动商贩",
		"position": Vector3(0.0, 1.0, -7.5),
		"color": Color("#f4b942"),
		"type": "merchant",
		"lines": []
	},
	{
		"name": "顾言",
		"role": "策略社牌战挑战者",
		"position": Vector3(5.5, 1.0, -9.0),
		"color": Color("#a78bfa"),
		"type": "duelist",
		"lines": ["来打一局？我会提前亮出下一次进攻意图。"]
	}
]

func _ready() -> void:
	_setup_world()
	_setup_player()
	_setup_npcs()
	_setup_ui()

func _physics_process(delta: float) -> void:
	_move_player(delta)
	_update_camera()
	_update_nearby_npc()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E and not _is_modal_open():
			var npc_distance := INF
			var gate_distance := INF
			if nearby_npc != null:
				npc_distance = player.global_position.distance_to(nearby_npc.global_position)
			if nearby_gate != null:
				gate_distance = player.global_position.distance_to(nearby_gate.get_meta("interaction_position"))
			if gate_distance < npc_distance:
				_enter_gate()
			elif nearby_npc != null:
				_interact_with_npc(nearby_npc)
		elif event.keycode == KEY_I and not _is_modal_open():
			_toggle_inventory()
		elif event.keycode == KEY_ESCAPE:
			if battle_panel != null and battle_panel.visible:
				_close_battle()
			elif deck_view_panel != null and deck_view_panel.visible:
				deck_view_panel.visible = false
			elif codex_panel != null and codex_panel.visible:
				codex_panel.visible = false
			else:
				_close_dialogue()
				_close_shop()

func _setup_world() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#08111f")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8db4d9")
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	add_child(environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_color = Color("#b9d7ff")
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)

	var ground := StaticBody3D.new()
	ground.name = "Ground"
	var ground_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(24, 24)
	ground_mesh.mesh = plane
	ground_mesh.material_override = _material(Color("#17283b"))
	ground.add_child(ground_mesh)
	var ground_collision := CollisionShape3D.new()
	var ground_shape := BoxShape3D.new()
	ground_shape.size = Vector3(24, 0.2, 24)
	ground_collision.shape = ground_shape
	ground_collision.position.y = -0.1
	ground.add_child(ground_collision)
	add_child(ground)

	for marker in [Vector3(0, 0.03, 0), Vector3(0, 0.03, -4), Vector3(4, 0.03, -4)]:
		var ring := MeshInstance3D.new()
		var ring_mesh := CylinderMesh.new()
		ring_mesh.top_radius = 1.35
		ring_mesh.bottom_radius = 1.35
		ring_mesh.height = 0.03
		ring.mesh = ring_mesh
		ring.position = marker
		ring.material_override = _material(Color("#213f5a"))
		add_child(ring)

	for x in [-8.0, 8.0]:
		var pillar := MeshInstance3D.new()
		var pillar_mesh := BoxMesh.new()
		pillar_mesh.size = Vector3(0.25, 4.0, 0.25)
		pillar.mesh = pillar_mesh
		pillar.position = Vector3(x, 2.0, -8.0)
		pillar.material_override = _material(Color("#1ca6a8"), true)
		add_child(pillar)
	_setup_gate()

func _setup_gate() -> void:
	var gate := Node3D.new()
	gate.name = "TransitGate"
	gate.position = Vector3(7.8, 0, -4.5)
	gate.set_meta("target_scene", "res://TransitRoom.tscn")

	var frame_material := _material(Color("#1ca6a8"), true)
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.42, 3.5, 0.42)
	for z_offset in [-1.8, 1.8]:
		var post := MeshInstance3D.new()
		post.mesh = post_mesh
		post.material_override = frame_material
		post.position = Vector3(0, 1.75, z_offset)
		gate.add_child(post)

	var lintel := MeshInstance3D.new()
	var lintel_mesh := BoxMesh.new()
	lintel_mesh.size = Vector3(0.48, 0.45, 4.0)
	lintel.mesh = lintel_mesh
	lintel.material_override = frame_material
	lintel.position = Vector3(0, 3.5, 0)
	gate.add_child(lintel)

	var veil := MeshInstance3D.new()
	var veil_mesh := BoxMesh.new()
	veil_mesh.size = Vector3(0.06, 2.95, 3.25)
	veil.mesh = veil_mesh
	var veil_material := _material(Color("#63f3e5"), true)
	veil_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	veil_material.albedo_color.a = 0.2
	veil_material.emission_energy_multiplier = 1.2
	veil.material_override = veil_material
	veil.position = Vector3(-0.04, 1.72, 0)
	gate.add_child(veil)

	var gate_tag := Label3D.new()
	gate_tag.text = "区域传送门\nTRANSIT GATE"
	gate_tag.position = Vector3(-0.3, 4.0, 0)
	gate_tag.font_size = 36
	gate_tag.outline_size = 8
	gate_tag.modulate = Color("#d7fffa")
	gate.add_child(gate_tag)
	add_child(gate)
	gate.set_meta("interaction_position", gate.to_global(Vector3(-2.2, 1.0, 0)))

func _setup_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(5.3, 1.0, -4.5)
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.height = 1.8
	capsule.radius = 0.38
	body.mesh = capsule
	body.material_override = _material(Color("#f4f7ff"))
	player.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.height = 1.8
	shape.radius = 0.38
	collision.shape = shape
	player.add_child(collision)
	add_child(player)

	camera = Camera3D.new()
	camera.current = true
	camera.fov = 65.0
	add_child(camera)

func _setup_npcs() -> void:
	for data in npcs:
		var npc := CharacterBody3D.new()
		npc.name = data["name"]
		npc.position = data["position"]
		npc.set_meta("dialogue_data", data)
		npc.set_meta("npc_type", data.get("type", "dialogue"))
		var body := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.height = 1.9
		capsule.radius = 0.42
		body.mesh = capsule
		body.material_override = _material(data["color"], true)
		npc.add_child(body)
		var collision := CollisionShape3D.new()
		var shape := CapsuleShape3D.new()
		shape.height = 1.9
		shape.radius = 0.42
		collision.shape = shape
		npc.add_child(collision)
		var name_tag := Label3D.new()
		name_tag.text = data["name"] + "  ·  " + data["role"]
		name_tag.position = Vector3(0, 1.5, 0)
		name_tag.font_size = 32
		name_tag.outline_size = 8
		name_tag.modulate = Color("#e9f5ff")
		npc.add_child(name_tag)
		add_child(npc)

func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	interaction_hint = Label.new()
	interaction_hint.position = Vector2(40, 40)
	interaction_hint.add_theme_font_size_override("font_size", 22)
	interaction_hint.add_theme_color_override("font_color", Color("#d9f1ff"))
	interaction_hint.text = "WASD 移动 · 靠近 NPC 后按 E 对话"
	layer.add_child(interaction_hint)

	dialogue_panel = Panel.new()
	dialogue_panel.position = Vector2(60, 500)
	dialogue_panel.size = Vector2(1160, 155)
	dialogue_panel.visible = false
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.06, 0.11, 0.94)
	panel_style.border_color = Color("#35d0d0")
	panel_style.set_border_width_all(2)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	dialogue_panel.add_theme_stylebox_override("panel", panel_style)
	layer.add_child(dialogue_panel)

	dialogue_title = Label.new()
	dialogue_title.position = Vector2(24, 18)
	dialogue_title.add_theme_font_size_override("font_size", 24)
	dialogue_title.add_theme_color_override("font_color", Color("#5eead4"))
	dialogue_panel.add_child(dialogue_title)

	dialogue_text = Label.new()
	dialogue_text.position = Vector2(24, 58)
	dialogue_text.size = Vector2(1090, 65)
	dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_text.add_theme_font_size_override("font_size", 22)
	dialogue_text.add_theme_color_override("font_color", Color("#f1f7ff"))
	dialogue_panel.add_child(dialogue_text)

	economy_hud = Panel.new()
	economy_hud.position = Vector2(930, 32)
	economy_hud.size = Vector2(310, 260)
	var hud_style := StyleBoxFlat.new()
	hud_style.bg_color = Color(0.025, 0.06, 0.11, 0.88)
	hud_style.border_color = Color("#47718c")
	hud_style.set_border_width_all(1)
	hud_style.set_corner_radius_all(8)
	economy_hud.add_theme_stylebox_override("panel", hud_style)
	layer.add_child(economy_hud)

	economy_text = Label.new()
	economy_text.position = Vector2(18, 14)
	economy_text.size = Vector2(274, 174)
	economy_text.add_theme_font_size_override("font_size", 19)
	economy_text.add_theme_color_override("font_color", Color("#edf7ff"))
	economy_hud.add_child(economy_text)

	deck_view_button = Button.new()
	deck_view_button.position = Vector2(18, 196)
	deck_view_button.size = Vector2(130, 40)
	deck_view_button.text = "牌组"
	deck_view_button.add_theme_font_size_override("font_size", 16)
	deck_view_button.pressed.connect(_open_deck_view)
	economy_hud.add_child(deck_view_button)
	codex_button = Button.new()
	codex_button.position = Vector2(162, 196)
	codex_button.size = Vector2(130, 40)
	codex_button.text = "卡牌图鉴"
	codex_button.add_theme_font_size_override("font_size", 16)
	codex_button.pressed.connect(_open_codex)
	economy_hud.add_child(codex_button)

	shop_panel = Panel.new()
	shop_panel.position = Vector2(60, 290)
	shop_panel.size = Vector2(1160, 365)
	shop_panel.visible = false
	var shop_style := StyleBoxFlat.new()
	shop_style.bg_color = Color(0.025, 0.06, 0.11, 0.97)
	shop_style.border_color = Color("#f4b942")
	shop_style.set_border_width_all(2)
	shop_style.set_corner_radius_all(10)
	shop_panel.add_theme_stylebox_override("panel", shop_style)
	layer.add_child(shop_panel)

	shop_title = Label.new()
	shop_title.position = Vector2(24, 16)
	shop_title.add_theme_font_size_override("font_size", 26)
	shop_title.add_theme_color_override("font_color", Color("#ffd166"))
	shop_panel.add_child(shop_title)

	shop_balance = Label.new()
	shop_balance.position = Vector2(820, 20)
	shop_balance.size = Vector2(300, 32)
	shop_balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	shop_balance.add_theme_font_size_override("font_size", 20)
	shop_balance.add_theme_color_override("font_color", Color("#eaf6ff"))
	shop_panel.add_child(shop_balance)

	var columns := HBoxContainer.new()
	columns.position = Vector2(24, 62)
	columns.size = Vector2(1110, 235)
	columns.add_theme_constant_override("separation", 24)
	shop_panel.add_child(columns)

	shop_rows = VBoxContainer.new()
	shop_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_rows.add_theme_constant_override("separation", 8)
	columns.add_child(shop_rows)

	shop_feedback = Label.new()
	shop_feedback.position = Vector2(24, 310)
	shop_feedback.size = Vector2(850, 34)
	shop_feedback.add_theme_font_size_override("font_size", 18)
	shop_feedback.add_theme_color_override("font_color", Color("#9ee8d7"))
	shop_panel.add_child(shop_feedback)

	var close_hint := Label.new()
	close_hint.position = Vector2(900, 310)
	close_hint.size = Vector2(230, 34)
	close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	close_hint.text = "[Esc] 关闭商店"
	close_hint.add_theme_font_size_override("font_size", 18)
	close_hint.add_theme_color_override("font_color", Color("#a9bfd1"))
	shop_panel.add_child(close_hint)
	_setup_deck_and_codex_ui(layer)
	_setup_battle_ui(layer)

	_refresh_economy_hud()

func _setup_deck_and_codex_ui(layer: CanvasLayer) -> void:
	deck_view_panel = _make_collection_panel(Vector2(290, 94), Vector2(700, 532), Color("#35d0c2"))
	deck_view_panel.visible = false
	layer.add_child(deck_view_panel)
	deck_view_title = _make_collection_title("当前牌组", Color("#99f6e4"))
	deck_view_panel.add_child(deck_view_title)
	deck_view_summary = Label.new()
	deck_view_summary.position = Vector2(30, 62)
	deck_view_summary.size = Vector2(640, 32)
	deck_view_summary.add_theme_font_size_override("font_size", 17)
	deck_view_summary.add_theme_color_override("font_color", Color("#c5d4e5"))
	deck_view_panel.add_child(deck_view_summary)
	deck_view_rows = VBoxContainer.new()
	deck_view_rows.position = Vector2(30, 112)
	deck_view_rows.size = Vector2(640, 330)
	deck_view_rows.add_theme_constant_override("separation", 10)
	deck_view_panel.add_child(deck_view_rows)
	var deck_close := _make_collection_close_button()
	deck_close.pressed.connect(func(): deck_view_panel.visible = false)
	deck_view_panel.add_child(deck_close)

	codex_panel = _make_collection_panel(Vector2(290, 94), Vector2(700, 532), Color("#a78bfa"))
	codex_panel.visible = false
	layer.add_child(codex_panel)
	codex_title = _make_collection_title("卡牌图鉴", Color("#ddd6fe"))
	codex_panel.add_child(codex_title)
	codex_summary = Label.new()
	codex_summary.position = Vector2(30, 62)
	codex_summary.size = Vector2(640, 32)
	codex_summary.add_theme_font_size_override("font_size", 17)
	codex_summary.add_theme_color_override("font_color", Color("#c5d4e5"))
	codex_panel.add_child(codex_summary)
	codex_rows = VBoxContainer.new()
	codex_rows.position = Vector2(30, 112)
	codex_rows.size = Vector2(640, 330)
	codex_rows.add_theme_constant_override("separation", 10)
	codex_panel.add_child(codex_rows)
	var codex_close := _make_collection_close_button()
	codex_close.pressed.connect(func(): codex_panel.visible = false)
	codex_panel.add_child(codex_close)

	_refresh_deck_view()
	_refresh_codex()

func _make_collection_panel(position: Vector2, size: Vector2, accent: Color) -> Panel:
	var panel := Panel.new()
	panel.position = position
	panel.size = size
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0b1020")
	style.border_color = accent
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _make_collection_title(text: String, color: Color) -> Label:
	var title := Label.new()
	title.position = Vector2(30, 22)
	title.size = Vector2(620, 32)
	title.text = text
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", color)
	return title

func _make_collection_close_button() -> Button:
	var button := Button.new()
	button.position = Vector2(510, 464)
	button.size = Vector2(160, 42)
	button.text = "关闭  [Esc]"
	button.add_theme_font_size_override("font_size", 16)
	return button

func _open_deck_view() -> void:
	if _is_modal_open():
		return
	_refresh_deck_view()
	deck_view_panel.visible = true

func _open_codex() -> void:
	if _is_modal_open():
		return
	_refresh_codex()
	codex_panel.visible = true

func _refresh_deck_view() -> void:
	if deck_view_rows == null:
		return
	_clear_collection_rows(deck_view_rows)
	deck_view_summary.text = "共 %d 张卡牌  ·  固定测试牌组" % player_deck.size()
	for card_id in battle_card_definitions:
		var count: int = player_deck.count(card_id)
		if count <= 0:
			continue
		deck_view_rows.add_child(_make_collection_card_row(card_id, "%d 张" % count))

func _refresh_codex() -> void:
	if codex_rows == null:
		return
	_clear_collection_rows(codex_rows)
	codex_summary.text = "已收录 %d / %d 种卡牌" % [battle_card_definitions.size(), battle_card_definitions.size()]
	for card_id in battle_card_definitions:
		var count: int = player_deck.count(card_id)
		var ownership := "牌组 ×%d" % count if count > 0 else "尚未加入牌组"
		codex_rows.add_child(_make_collection_card_row(card_id, ownership))

func _clear_collection_rows(rows: VBoxContainer) -> void:
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()

func _make_collection_card_row(card_id: String, trailing_text: String) -> Panel:
	var card: Dictionary = battle_card_definitions[card_id]
	var category := _card_category(String(card["type"]))
	var accent := _card_accent(String(card["type"]))
	var row := Panel.new()
	row.custom_minimum_size = Vector2(640, 72)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#151e30")
	style.border_color = Color(accent, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	row.add_theme_stylebox_override("panel", style)
	var category_label := Label.new()
	category_label.position = Vector2(14, 12)
	category_label.size = Vector2(74, 24)
	category_label.text = category
	category_label.add_theme_font_size_override("font_size", 15)
	category_label.add_theme_color_override("font_color", accent)
	row.add_child(category_label)
	var name_label := Label.new()
	name_label.position = Vector2(98, 8)
	name_label.size = Vector2(270, 26)
	name_label.text = "%s  ·  每回合限 %d 张" % [card["name"], BATTLE_CARD_TYPE_LIMIT]
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color", Color("#f1f5f9"))
	row.add_child(name_label)
	var description := Label.new()
	description.position = Vector2(98, 38)
	description.size = Vector2(420, 22)
	description.text = card["description"]
	description.add_theme_font_size_override("font_size", 14)
	description.add_theme_color_override("font_color", Color("#aebbd0"))
	row.add_child(description)
	var trailing := Label.new()
	trailing.position = Vector2(510, 20)
	trailing.size = Vector2(112, 24)
	trailing.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	trailing.text = trailing_text
	trailing.add_theme_font_size_override("font_size", 15)
	trailing.add_theme_color_override("font_color", Color("#d4dced"))
	row.add_child(trailing)
	return row

func _setup_battle_ui(layer: CanvasLayer) -> void:
	battle_panel = Panel.new()
	battle_panel.position = Vector2(44, 34)
	battle_panel.size = Vector2(1192, 652)
	battle_panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0b1020")
	style.border_color = Color("#7164b8")
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	battle_panel.add_theme_stylebox_override("panel", style)
	layer.add_child(battle_panel)

	var title := Label.new()
	title.position = Vector2(32, 18)
	title.size = Vector2(650, 30)
	title.text = "STRATEGY CLUB  //  牌战协议"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color("#a99cf2"))
	battle_panel.add_child(title)

	battle_turn_label = Label.new()
	battle_turn_label.position = Vector2(870, 18)
	battle_turn_label.size = Vector2(290, 30)
	battle_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	battle_turn_label.text = "DUEL  01"
	battle_turn_label.add_theme_font_size_override("font_size", 16)
	battle_turn_label.add_theme_color_override("font_color", Color("#c4b5fd"))
	battle_panel.add_child(battle_turn_label)

	var player_status := _make_battle_status_panel(Vector2(32, 62), Vector2(540, 94), Color("#1d827d"))
	battle_panel.add_child(player_status)
	var player_name := Label.new()
	player_name.position = Vector2(18, 10)
	player_name.text = "你  /  PLAYER"
	player_name.add_theme_font_size_override("font_size", 17)
	player_name.add_theme_color_override("font_color", Color("#99f6e4"))
	player_status.add_child(player_name)
	battle_player_hp_text = Label.new()
	battle_player_hp_text.position = Vector2(430, 10)
	battle_player_hp_text.size = Vector2(90, 26)
	battle_player_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	battle_player_hp_text.add_theme_font_size_override("font_size", 17)
	battle_player_hp_text.add_theme_color_override("font_color", Color("#e6fffb"))
	player_status.add_child(battle_player_hp_text)
	battle_player_hp_bar = _make_battle_hp_bar(Color("#35d0c2"))
	battle_player_hp_bar.position = Vector2(18, 52)
	battle_player_hp_bar.size = Vector2(504, 20)
	player_status.add_child(battle_player_hp_bar)

	var opponent_status := _make_battle_status_panel(Vector2(620, 62), Vector2(540, 94), Color("#7c54b5"))
	battle_panel.add_child(opponent_status)
	var opponent_name := Label.new()
	opponent_name.position = Vector2(18, 10)
	opponent_name.text = "顾言  /  DUELIST"
	opponent_name.add_theme_font_size_override("font_size", 17)
	opponent_name.add_theme_color_override("font_color", Color("#ddd6fe"))
	opponent_status.add_child(opponent_name)
	battle_opponent_hp_text = Label.new()
	battle_opponent_hp_text.position = Vector2(430, 10)
	battle_opponent_hp_text.size = Vector2(90, 26)
	battle_opponent_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	battle_opponent_hp_text.add_theme_font_size_override("font_size", 17)
	battle_opponent_hp_text.add_theme_color_override("font_color", Color("#f4edff"))
	opponent_status.add_child(battle_opponent_hp_text)
	battle_opponent_hp_bar = _make_battle_hp_bar(Color("#b38cff"))
	battle_opponent_hp_bar.position = Vector2(18, 52)
	battle_opponent_hp_bar.size = Vector2(504, 20)
	opponent_status.add_child(battle_opponent_hp_bar)

	battle_status = Label.new()
	battle_status.position = Vector2(32, 170)
	battle_status.size = Vector2(1128, 34)
	battle_status.add_theme_font_size_override("font_size", 18)
	battle_status.add_theme_color_override("font_color", Color("#e6edf7"))
	battle_panel.add_child(battle_status)

	battle_intent = Label.new()
	battle_intent.position = Vector2(32, 208)
	battle_intent.size = Vector2(1128, 38)
	battle_intent.add_theme_font_size_override("font_size", 17)
	battle_intent.add_theme_color_override("font_color", Color("#fde68a"))
	battle_panel.add_child(battle_intent)

	battle_deck_label = Label.new()
	battle_deck_label.position = Vector2(32, 252)
	battle_deck_label.size = Vector2(1128, 26)
	battle_deck_label.text = "你的手牌"
	battle_deck_label.add_theme_font_size_override("font_size", 16)
	battle_deck_label.add_theme_color_override("font_color", Color("#9aa8bd"))
	battle_panel.add_child(battle_deck_label)

	battle_cards_container = HBoxContainer.new()
	battle_cards_container.position = Vector2(32, 274)
	battle_cards_container.size = Vector2(1128, 232)
	battle_cards_container.add_theme_constant_override("separation", 10)
	battle_panel.add_child(battle_cards_container)
	for index in range(5):
		var card_button := Button.new()
		card_button.custom_minimum_size = Vector2(210, 224)
		card_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_button.add_theme_stylebox_override("normal", _battle_card_style(Color("#151e30"), Color("#586a89")))
		card_button.add_theme_stylebox_override("hover", _battle_card_style(Color("#202c42"), Color("#dbeafe")))
		card_button.add_theme_stylebox_override("pressed", _battle_card_style(Color("#111827"), Color("#dbeafe")))
		card_button.add_theme_stylebox_override("disabled", _battle_card_style(Color("#111827"), Color("#344056")))
		var category_label := _make_card_label(Vector2(10, 8), Vector2(94, 22), 13, Color("#dbe7f5"))
		card_button.add_child(category_label)
		var limit_label := _make_card_label(Vector2(102, 8), Vector2(96, 22), 12, Color("#aebbd0"))
		limit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		card_button.add_child(limit_label)
		var name_label := _make_card_label(Vector2(10, 31), Vector2(188, 26), 18, Color("#f8fafc"))
		card_button.add_child(name_label)
		var art_panel := Panel.new()
		art_panel.position = Vector2(10, 61)
		art_panel.size = Vector2(188, 78)
		art_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_button.add_child(art_panel)
		var art_style := StyleBoxFlat.new()
		art_style.bg_color = Color("#0b1220")
		art_style.set_border_width_all(1)
		art_style.set_corner_radius_all(5)
		art_panel.add_theme_stylebox_override("panel", art_style)
		var art_symbol := _make_card_label(Vector2(0, 5), Vector2(188, 54), 34, Color.WHITE)
		art_symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		art_panel.add_child(art_symbol)
		var art_caption := _make_card_label(Vector2(0, 54), Vector2(188, 18), 10, Color("#91a0b8"))
		art_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		art_caption.text = "TAKEPA  /  DUEL PROTOCOL"
		art_panel.add_child(art_caption)
		var description_label := _make_card_label(Vector2(10, 145), Vector2(188, 48), 13, Color("#cbd5e1"))
		description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_button.add_child(description_label)
		var footer_label := _make_card_label(Vector2(10, 198), Vector2(188, 17), 10, Color("#71809a"))
		footer_label.text = "TACTIC CARD     /     FIELD TEST"
		card_button.add_child(footer_label)
		card_button.pressed.connect(_play_battle_card.bind(index))
		card_button.mouse_entered.connect(_animate_card_hover.bind(card_button, true))
		card_button.mouse_exited.connect(_animate_card_hover.bind(card_button, false))
		battle_cards_container.add_child(card_button)
		battle_card_buttons.append(card_button)
		battle_card_widgets.append({
			"category": category_label,
			"limit": limit_label,
			"name": name_label,
			"art": art_panel,
			"symbol": art_symbol,
			"description": description_label,
			"footer": footer_label
		})
	battle_animation_layer = Control.new()
	battle_animation_layer.position = Vector2.ZERO
	battle_animation_layer.size = battle_panel.size
	battle_animation_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battle_animation_layer.z_index = 10
	battle_panel.add_child(battle_animation_layer)

	battle_feedback = Label.new()
	battle_feedback.position = Vector2(32, 510)
	battle_feedback.size = Vector2(720, 42)
	battle_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	battle_feedback.add_theme_font_size_override("font_size", 17)
	battle_feedback.add_theme_color_override("font_color", Color("#b7f7e7"))
	battle_panel.add_child(battle_feedback)

	battle_end_button = Button.new()
	battle_end_button.position = Vector2(910, 560)
	battle_end_button.size = Vector2(250, 52)
	battle_end_button.text = "结束回合"
	battle_end_button.add_theme_font_size_override("font_size", 18)
	battle_end_button.pressed.connect(_end_battle_turn)
	battle_panel.add_child(battle_end_button)

	var leave_button := Button.new()
	leave_button.position = Vector2(32, 560)
	leave_button.size = Vector2(190, 52)
	leave_button.text = "退出牌战  [Esc]"
	leave_button.add_theme_font_size_override("font_size", 17)
	leave_button.pressed.connect(_close_battle)
	battle_panel.add_child(leave_button)

func _make_battle_status_panel(position: Vector2, size: Vector2, accent: Color) -> Panel:
	var panel := Panel.new()
	panel.position = position
	panel.size = size
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.08, 0.15, 0.96)
	style.border_color = Color(accent, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _make_battle_hp_bar(fill_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = 30
	bar.value = 30
	bar.show_percentage = false
	var background := StyleBoxFlat.new()
	background.bg_color = Color("#182238")
	background.set_corner_radius_all(6)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	return bar

func _battle_card_style(background_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _make_card_label(position: Vector2, size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = position
	label.size = size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _move_player(_delta: float) -> void:
	if _is_modal_open():
		player.velocity = Vector3.ZERO
		return
	var input_vector := Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	)
	if input_vector.length() > 1.0:
		input_vector = input_vector.normalized()
	var direction := Vector3(input_vector.x, 0, input_vector.y)
	player.velocity.x = direction.x * PLAYER_SPEED
	player.velocity.z = direction.z * PLAYER_SPEED
	player.velocity.y = 0.0
	player.move_and_slide()
	player.position.x = clamp(player.position.x, -10.5, 10.5)
	player.position.z = clamp(player.position.z, -10.5, 10.5)

func _update_camera() -> void:
	if player == null or camera == null:
		return
	var desired := player.global_position + Vector3(0, 4.6, 7.5)
	camera.global_position = camera.global_position.lerp(desired, 0.12)
	camera.look_at(player.global_position + Vector3(0, 0.8, 0), Vector3.UP)

func _update_nearby_npc() -> void:
	var closest: Node3D = null
	var closest_distance := INTERACTION_DISTANCE
	for child in get_children():
		if child is CharacterBody3D and child != player and child.has_meta("dialogue_data"):
			var distance := player.global_position.distance_to(child.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest = child
	nearby_npc = closest
	var closest_gate: Node3D
	var gate_distance := INTERACTION_DISTANCE
	for child in get_children():
		if child is Node3D and child.has_meta("target_scene"):
			var distance: float = player.global_position.distance_to(child.get_meta("interaction_position"))
			if distance < gate_distance:
				gate_distance = distance
				closest_gate = child
	nearby_gate = closest_gate
	if _is_modal_open():
		return
	var npc_distance := INF
	var current_gate_distance := INF
	if nearby_npc != null:
		npc_distance = player.global_position.distance_to(nearby_npc.global_position)
	if nearby_gate != null:
		current_gate_distance = player.global_position.distance_to(nearby_gate.get_meta("interaction_position"))
	if nearby_gate != null and current_gate_distance < npc_distance:
		interaction_hint.text = "区域传送门 · 按 E 传送至中转庭院"
	elif nearby_npc != null:
		var npc_type: String = nearby_npc.get_meta("npc_type", "dialogue")
		if npc_type == "merchant":
			interaction_hint.text = "与 %s 交易 · 按 E 打开商店" % nearby_npc.name
		elif npc_type == "duelist":
			interaction_hint.text = "挑战 %s · 按 E 开始牌战" % nearby_npc.name
		else:
			interaction_hint.text = "靠近 %s · 按 E 对话" % nearby_npc.name
	else:
		interaction_hint.text = "WASD 移动 · 靠近 NPC 或入口后按 E 交互"

func _interact_with_npc(npc: Node3D) -> void:
	var npc_type: String = npc.get_meta("npc_type", "dialogue")
	if npc_type == "merchant":
		_open_shop(npc)
	elif npc_type == "duelist":
		_start_battle(npc)
	else:
		_open_or_advance_dialogue(npc)

func _open_or_advance_dialogue(npc: Node3D) -> void:
	var data: Dictionary = npc.get_meta("dialogue_data")
	if not dialogue_panel.visible:
		dialogue_lines.clear()
		for line in data["lines"]:
			dialogue_lines.append(str(line))
		dialogue_index = 0
		dialogue_panel.visible = true
		dialogue_title.text = "%s  ·  %s" % [data["name"], data["role"]]
		dialogue_text.text = dialogue_lines[dialogue_index] + "\n\n[E] 继续   [Esc] 关闭"
	elif dialogue_index + 1 < dialogue_lines.size():
		dialogue_index += 1
		dialogue_text.text = dialogue_lines[dialogue_index] + "\n\n[E] 继续   [Esc] 关闭"
	else:
		_close_dialogue()

func _close_dialogue() -> void:
	dialogue_panel.visible = false

func _is_modal_open() -> bool:
	return (dialogue_panel != null and dialogue_panel.visible) or (shop_panel != null and shop_panel.visible) or (battle_panel != null and battle_panel.visible) or (deck_view_panel != null and deck_view_panel.visible) or (codex_panel != null and codex_panel.visible)

func _enter_gate() -> void:
	var error := get_tree().change_scene_to_file("res://TransitRoom.tscn")
	if error != OK:
		interaction_hint.text = "无法载入目的地：%s" % error

func _toggle_inventory() -> void:
	if economy_hud.visible:
		deck_view_panel.visible = false
		codex_panel.visible = false
	economy_hud.visible = not economy_hud.visible

func _open_shop(npc: Node3D) -> void:
	_close_dialogue()
	shop_title.text = "%s  ·  %s" % [npc.name, npc.get_meta("dialogue_data")["role"]]
	shop_feedback.text = "可以买入物品，也可以出售背包里的物品。"
	shop_panel.visible = true
	_refresh_shop()

func _close_shop() -> void:
	if shop_panel != null:
		shop_panel.visible = false

func _refresh_economy_hud() -> void:
	if economy_text == null:
		return
	var lines: Array[String] = ["背包  [I]", "", "金钱：%d 信用点" % money]
	for item in shop_items:
		var count: int = inventory.get(item["id"], 0)
		lines.append("%s：%d" % [item["name"], count])
	economy_text.text = "\n".join(lines)

func _refresh_shop() -> void:
	for child in shop_rows.get_children():
		child.queue_free()
	shop_balance.text = "余额：%d 信用点" % money
	for item in shop_items:
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 60
		row.add_theme_constant_override("separation", 12)
		shop_rows.add_child(row)

		var description := Label.new()
		description.text = "%s  ×%d\n%s" % [item["name"], inventory.get(item["id"], 0), item["description"]]
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		description.add_theme_font_size_override("font_size", 18)
		description.add_theme_color_override("font_color", Color("#edf7ff"))
		row.add_child(description)

		var buy_button := Button.new()
		buy_button.text = "购买  %d" % item["buy"]
		buy_button.custom_minimum_size = Vector2(130, 42)
		buy_button.pressed.connect(_buy_item.bind(item["id"]))
		row.add_child(buy_button)

		var sell_button := Button.new()
		sell_button.text = "出售  %d" % item["sell"]
		sell_button.custom_minimum_size = Vector2(130, 42)
		sell_button.disabled = inventory.get(item["id"], 0) <= 0
		sell_button.pressed.connect(_sell_item.bind(item["id"]))
		row.add_child(sell_button)
	_refresh_economy_hud()

func _buy_item(item_id: String) -> void:
	var item: Dictionary = _get_shop_item(item_id)
	if item.is_empty():
		return
	if money < item["buy"]:
		shop_feedback.text = "信用点不足，无法购买 %s。" % item["name"]
		return
	money -= item["buy"]
	inventory[item_id] = inventory.get(item_id, 0) + 1
	shop_feedback.text = "已购买 %s。" % item["name"]
	_refresh_shop()

func _sell_item(item_id: String) -> void:
	var item: Dictionary = _get_shop_item(item_id)
	if item.is_empty() or inventory.get(item_id, 0) <= 0:
		return
	inventory[item_id] -= 1
	money += item["sell"]
	shop_feedback.text = "已出售 %s。" % item["name"]
	_refresh_shop()

func _get_shop_item(item_id: String) -> Dictionary:
	for item in shop_items:
		if item["id"] == item_id:
			return item
	return {}

func _start_battle(npc: Node3D) -> void:
	_close_dialogue()
	_close_shop()
	battle_opponent = npc
	battle_player_hp = 30
	battle_opponent_hp = 30
	battle_block = 0
	battle_turn = 1
	battle_weakens_opponent = false
	battle_finished = false
	battle_won = false
	battle_feedback_text = "牌战开始。先读出对手意图，再决定出牌或结束回合。"
	battle_deck = player_deck.duplicate()
	battle_discard.clear()
	battle_type_uses.clear()
	battle_hand.clear()
	_draw_battle_cards_to_five()
	battle_panel.visible = true
	_refresh_battle_ui()

func _draw_battle_cards_to_five(animate := true) -> void:
	while battle_hand.size() < 5:
		if battle_deck.is_empty():
			if battle_discard.is_empty():
				break
			battle_deck = battle_discard.duplicate()
			battle_discard.clear()
			battle_deck.shuffle()
			if animate:
				battle_shuffle_pending = true
		var card_id: String = battle_deck.pop_front()
		battle_hand.append({"id": card_id})
		if animate:
			battle_pending_draw_indices.append(battle_hand.size() - 1)

func _play_battle_card(index: int) -> void:
	if not battle_panel.visible or battle_finished:
		return
	if index < 0 or index >= battle_hand.size():
		return
	var card_id: String = battle_hand[index]["id"]
	var card: Dictionary = battle_card_definitions[card_id]
	var card_origin := battle_cards_container.position + battle_card_buttons[index].position
	var card_type := String(card["type"])
	var used_count: int = battle_type_uses.get(card_type, 0)
	if used_count >= BATTLE_CARD_TYPE_LIMIT:
		battle_feedback_text = "本回合的%s牌已使用，%s牌每回合最多使用 %d 张。" % [_card_category(card_type), _card_category(card_type), BATTLE_CARD_TYPE_LIMIT]
		_refresh_battle_ui()
		return
	battle_type_uses[card_type] = used_count + 1
	match card_type:
		"damage":
			battle_opponent_hp = max(0, battle_opponent_hp - card["value"])
			battle_feedback_text = "你使用「%s」，造成 %d 点伤害。" % [card["name"], card["value"]]
		"block":
			battle_block += card["value"]
			battle_feedback_text = "你使用「%s」，获得 %d 点格挡。" % [card["name"], card["value"]]
		"disrupt":
			battle_opponent_hp = max(0, battle_opponent_hp - card["value"])
			battle_weakens_opponent = true
			battle_feedback_text = "你使用「%s」，造成 %d 点伤害并削弱本回合攻击。" % [card["name"], card["value"]]
		_:
			battle_feedback_text = "你使用「%s」。" % card["name"]
	battle_discard.append(card_id)
	battle_hand.remove_at(index)
	_animate_played_card(card, card_origin)
	if battle_opponent_hp <= 0:
		battle_finished = true
		battle_won = true
		battle_feedback_text = "你赢下了牌战。顾言认可了你的读牌能力。"
	_refresh_battle_ui()

func _end_battle_turn() -> void:
	if not battle_panel.visible:
		return
	if battle_finished:
		_close_battle()
		return
	var incoming_damage := 8
	if battle_weakens_opponent:
		incoming_damage = 4
	var blocked_damage: int = min(battle_block, incoming_damage)
	var actual_damage: int = incoming_damage - blocked_damage
	battle_block = max(0, battle_block - incoming_damage)
	battle_player_hp = max(0, battle_player_hp - actual_damage)
	if actual_damage == 0:
		battle_feedback_text = "顾言发动 %d 点攻击，但被你的格挡完全挡下。" % incoming_damage
	else:
		battle_feedback_text = "顾言发动 %d 点攻击，你受到 %d 点伤害。" % [incoming_damage, actual_damage]
	if battle_player_hp <= 0:
		battle_finished = true
		battle_won = false
		battle_feedback_text = "你输掉了牌战。调整出牌节奏后再来挑战。"
	else:
		battle_turn += 1
		battle_block = 0
		battle_weakens_opponent = false
		battle_type_uses.clear()
		_draw_battle_cards_to_five()
	_refresh_battle_ui()

func _close_battle() -> void:
	if battle_panel != null:
		battle_panel.visible = false
	battle_opponent = null
	battle_finished = false
	battle_won = false
	battle_hand.clear()
	battle_deck.clear()
	battle_discard.clear()
	battle_type_uses.clear()

func _refresh_battle_ui() -> void:
	if battle_panel == null or not battle_panel.visible:
		return
	battle_turn_label.text = "DUEL  %02d" % battle_turn
	battle_player_hp_text.text = "%d / 30" % battle_player_hp
	battle_opponent_hp_text.text = "%d / 30" % battle_opponent_hp
	battle_player_hp_bar.value = battle_player_hp
	battle_opponent_hp_bar.value = battle_opponent_hp
	battle_status.text = "本回合牌类额度  %s     格挡  %d" % [_battle_type_limit_summary(), battle_block]
	battle_deck_label.text = "你的手牌     %d / 5 张  ·  牌库 %d  ·  弃牌 %d" % [battle_hand.size(), battle_deck.size(), battle_discard.size()]
	if battle_finished:
		battle_intent.text = "牌战结束 · %s" % ("胜利" if battle_won else "失败")
	else:
		battle_intent.text = "⚠ 顾言准备普通击打   ·   预计造成 8 点伤害   ·   旋球扰乱可降低至 4 点"
	battle_feedback.text = battle_feedback_text
	battle_end_button.text = "离开牌战" if battle_finished else "结束回合"
	battle_end_button.disabled = false
	for index in range(battle_card_buttons.size()):
		var button := battle_card_buttons[index]
		if index < battle_hand.size():
			var card_id: String = battle_hand[index]["id"]
			var card: Dictionary = battle_card_definitions[card_id]
			var card_type := String(card["type"])
			var category := _card_category(card_type)
			var accent := _card_accent(card_type)
			var used_count: int = battle_type_uses.get(card_type, 0)
			var widgets: Dictionary = battle_card_widgets[index]
			var category_label: Label = widgets["category"]
			category_label.text = category.to_upper()
			category_label.add_theme_color_override("font_color", accent)
			var limit_label: Label = widgets["limit"]
			limit_label.text = "%d / %d" % [used_count, BATTLE_CARD_TYPE_LIMIT]
			limit_label.add_theme_color_override("font_color", accent if used_count == 0 else Color("#64748b"))
			var name_label: Label = widgets["name"]
			name_label.text = card["name"]
			var art_panel: Panel = widgets["art"]
			var art_style: StyleBoxFlat = art_panel.get_theme_stylebox("panel").duplicate()
			art_style.border_color = Color(accent, 0.65)
			art_panel.add_theme_stylebox_override("panel", art_style)
			var art_symbol: Label = widgets["symbol"]
			art_symbol.text = _card_symbol(card_type)
			art_symbol.add_theme_color_override("font_color", accent)
			var description_label: Label = widgets["description"]
			description_label.text = card["description"]
			var footer_label: Label = widgets["footer"]
			footer_label.text = "TYPE %s     /     FIELD TEST" % card_type.to_upper()
			button.add_theme_stylebox_override("normal", _battle_card_style(Color("#202c42"), Color(accent, 0.75)))
			button.add_theme_stylebox_override("hover", _battle_card_style(Color("#2a3a56"), accent))
			button.add_theme_stylebox_override("pressed", _battle_card_style(Color("#151f32"), accent))
			button.disabled = battle_finished or used_count >= BATTLE_CARD_TYPE_LIMIT
			button.modulate = Color("#64748b") if button.disabled else Color.WHITE
		else:
			var empty_widgets: Dictionary = battle_card_widgets[index]
			(empty_widgets["category"] as Label).text = "EMPTY SLOT"
			(empty_widgets["limit"] as Label).text = "—"
			(empty_widgets["name"] as Label).text = "待抽取"
			(empty_widgets["symbol"] as Label).text = "·"
			(empty_widgets["description"] as Label).text = "等待下一轮补牌"
			(empty_widgets["footer"] as Label).text = "TAKEPA  /  CARD SLOT"
			button.disabled = true
			button.modulate = Color("#64748b")
	if battle_shuffle_pending:
		battle_shuffle_pending = false
		_animate_shuffle()
		if not battle_pending_draw_indices.is_empty():
			var delayed_indices := battle_pending_draw_indices.duplicate()
			battle_pending_draw_indices.clear()
			get_tree().create_timer(0.28).timeout.connect(_animate_draw_cards.bind(delayed_indices))
	else:
		if not battle_pending_draw_indices.is_empty():
			var drawn_indices := battle_pending_draw_indices.duplicate()
			battle_pending_draw_indices.clear()
			_animate_draw_cards(drawn_indices)

func _battle_type_limit_summary() -> String:
	var type_order: Array[String] = []
	for card_id in battle_card_definitions:
		var card_type := String(battle_card_definitions[card_id]["type"])
		if not type_order.has(card_type):
			type_order.append(card_type)
	var summary: Array[String] = []
	for card_type in type_order:
		summary.append("%s %d/%d" % [_card_category(card_type), battle_type_uses.get(card_type, 0), BATTLE_CARD_TYPE_LIMIT])
	return "  ·  ".join(summary)

func _card_category(card_type: String) -> String:
	match card_type:
		"damage":
			return "攻击"
		"block":
			return "防御"
		"disrupt":
			return "干扰"
		_:
			return card_type

func _card_accent(card_type: String) -> Color:
	match card_type:
		"damage":
			return Color("#f87171")
		"block":
			return Color("#5eead4")
		"disrupt":
			return Color("#c4b5fd")
		_:
			return Color("#fbbf24")

func _card_symbol(card_type: String) -> String:
	match card_type:
		"damage":
			return "▲"
		"block":
			return "◇"
		"disrupt":
			return "✦"
		_:
			return "•"

func _animate_card_hover(button: Button, hovered: bool) -> void:
	if not is_instance_valid(button) or button.disabled:
		return
	button.pivot_offset = button.size / 2.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(1.035, 1.035) if hovered else Vector2.ONE, 0.12)

func _animate_draw_cards(indices: Array) -> void:
	for index in indices:
		if index < 0 or index >= battle_card_buttons.size() or index >= battle_hand.size():
			continue
		var button := battle_card_buttons[index]
		button.pivot_offset = button.size / 2.0
		button.modulate = Color(1, 1, 1, 0)
		button.scale = Vector2(0.84, 0.84)
		button.rotation = deg_to_rad(4.0 if index % 2 == 0 else -4.0)
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(button, "modulate", Color.WHITE, 0.18)
		tween.parallel().tween_property(button, "scale", Vector2.ONE, 0.28)
		tween.parallel().tween_property(button, "rotation", 0.0, 0.28)

func _animate_played_card(card: Dictionary, origin: Vector2) -> void:
	if battle_animation_layer == null:
		return
	var ghost := Panel.new()
	ghost.position = origin
	ghost.size = Vector2(210, 224)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.pivot_offset = ghost.size / 2.0
	var accent := _card_accent(String(card["type"]))
	ghost.add_theme_stylebox_override("panel", _battle_card_style(Color("#202c42"), accent))
	var label := _make_card_label(Vector2(12, 18), Vector2(186, 110), 20, Color("#f8fafc"))
	label.text = "%s\n\n%s" % [_card_category(String(card["type"])), card["name"]]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ghost.add_child(label)
	battle_animation_layer.add_child(ghost)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(ghost, "position", Vector2(1010, 448), 0.34)
	tween.parallel().tween_property(ghost, "scale", Vector2(0.52, 0.52), 0.34)
	tween.parallel().tween_property(ghost, "modulate", Color(1, 1, 1, 0), 0.34)
	tween.tween_callback(ghost.queue_free)

func _animate_shuffle() -> void:
	for index in range(battle_card_buttons.size()):
		var button := battle_card_buttons[index]
		button.pivot_offset = button.size / 2.0
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_interval(index * 0.025)
		tween.tween_property(button, "rotation", deg_to_rad(5.0 if index % 2 == 0 else -5.0), 0.08)
		tween.tween_property(button, "rotation", deg_to_rad(-4.0 if index % 2 == 0 else 4.0), 0.08)
		tween.tween_property(button, "rotation", 0.0, 0.1)

func _material(color: Color, emissive := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 0.5
	return material
