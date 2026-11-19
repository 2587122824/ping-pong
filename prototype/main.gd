extends Node3D

const PLAYER_SPEED := 5.0
const INTERACTION_DISTANCE := 3.2

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
var battle_end_button: Button
var battle_opponent: Node3D
var dialogue_index := 0
var dialogue_lines: Array[String] = []
var battle_player_hp := 30
var battle_opponent_hp := 30
var battle_energy := 3
var battle_block := 0
var battle_turn := 1
var battle_weakens_opponent := false
var battle_finished := false
var battle_won := false
var battle_hand: Array[Dictionary] = []
var battle_deck: Array[String] = []
var battle_discard: Array[String] = []
var battle_feedback_text := ""

var battle_card_definitions := {
	"forehand": {"name": "正手击打", "cost": 1, "type": "damage", "value": 6, "description": "造成 6 点伤害"},
	"backhand": {"name": "反手快攻", "cost": 1, "type": "damage", "value": 4, "description": "造成 4 点伤害，消耗低"},
	"guard": {"name": "架拍格挡", "cost": 1, "type": "block", "value": 7, "description": "抵挡本回合 7 点伤害"},
	"curve": {"name": "旋球扰乱", "cost": 2, "type": "disrupt", "value": 3, "description": "造成 3 点伤害，并削弱对手本回合攻击"}
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
	economy_hud.size = Vector2(310, 210)
	var hud_style := StyleBoxFlat.new()
	hud_style.bg_color = Color(0.025, 0.06, 0.11, 0.88)
	hud_style.border_color = Color("#47718c")
	hud_style.set_border_width_all(1)
	hud_style.set_corner_radius_all(8)
	economy_hud.add_theme_stylebox_override("panel", hud_style)
	layer.add_child(economy_hud)

	economy_text = Label.new()
	economy_text.position = Vector2(18, 14)
	economy_text.size = Vector2(270, 180)
	economy_text.add_theme_font_size_override("font_size", 19)
	economy_text.add_theme_color_override("font_color", Color("#edf7ff"))
	economy_hud.add_child(economy_text)

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
	_setup_battle_ui(layer)

	_refresh_economy_hud()

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
	battle_cards_container.position = Vector2(32, 280)
	battle_cards_container.size = Vector2(1128, 192)
	battle_cards_container.add_theme_constant_override("separation", 14)
	battle_panel.add_child(battle_cards_container)
	for index in range(3):
		var card_button := Button.new()
		card_button.custom_minimum_size = Vector2(360, 192)
		card_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_button.add_theme_font_size_override("font_size", 18)
		card_button.add_theme_stylebox_override("normal", _battle_card_style(Color("#27344d"), Color("#586a89")))
		card_button.add_theme_stylebox_override("hover", _battle_card_style(Color("#354565"), Color("#b6c8ff")))
		card_button.add_theme_stylebox_override("pressed", _battle_card_style(Color("#17243a"), Color("#dbeafe")))
		card_button.add_theme_stylebox_override("disabled", _battle_card_style(Color("#161f30"), Color("#344056")))
		card_button.pressed.connect(_play_battle_card.bind(index))
		battle_cards_container.add_child(card_button)
		battle_card_buttons.append(card_button)

	battle_feedback = Label.new()
	battle_feedback.position = Vector2(32, 493)
	battle_feedback.size = Vector2(720, 50)
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
	style.set_corner_radius_all(12)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style

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
	return (dialogue_panel != null and dialogue_panel.visible) or (shop_panel != null and shop_panel.visible) or (battle_panel != null and battle_panel.visible)

func _enter_gate() -> void:
	var error := get_tree().change_scene_to_file("res://TransitRoom.tscn")
	if error != OK:
		interaction_hint.text = "无法载入目的地：%s" % error

func _toggle_inventory() -> void:
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
	battle_energy = 3
	battle_block = 0
	battle_turn = 1
	battle_weakens_opponent = false
	battle_finished = false
	battle_won = false
	battle_feedback_text = "牌战开始。先读出对手意图，再决定出牌或结束回合。"
	battle_deck = ["forehand", "backhand", "guard", "curve", "forehand", "backhand", "guard", "curve", "forehand", "backhand"]
	battle_discard.clear()
	battle_hand.clear()
	_draw_battle_cards_to_three()
	battle_panel.visible = true
	_refresh_battle_ui()

func _draw_battle_cards_to_three() -> void:
	while battle_hand.size() < 3:
		if battle_deck.is_empty():
			if battle_discard.is_empty():
				break
			battle_deck = battle_discard.duplicate()
			battle_discard.clear()
			battle_deck.shuffle()
		var card_id: String = battle_deck.pop_front()
		battle_hand.append({"id": card_id})

func _play_battle_card(index: int) -> void:
	if not battle_panel.visible or battle_finished:
		return
	if index < 0 or index >= battle_hand.size():
		return
	var card_id: String = battle_hand[index]["id"]
	var card: Dictionary = battle_card_definitions[card_id]
	if battle_energy < card["cost"]:
		battle_feedback_text = "能量不足，无法使用「%s」。" % card["name"]
		_refresh_battle_ui()
		return
	battle_energy -= card["cost"]
	match card["type"]:
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
	battle_discard.append(card_id)
	battle_hand.remove_at(index)
	if battle_opponent_hp <= 0:
		battle_finished = true
		battle_won = true
		battle_feedback_text = "你赢下了牌战。顾言认可了你的读牌能力。"
	else:
		_draw_battle_cards_to_three()
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
		battle_energy = 3
		battle_block = 0
		battle_weakens_opponent = false
		_draw_battle_cards_to_three()
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

func _refresh_battle_ui() -> void:
	if battle_panel == null or not battle_panel.visible:
		return
	battle_turn_label.text = "DUEL  %02d" % battle_turn
	battle_player_hp_text.text = "%d / 30" % battle_player_hp
	battle_opponent_hp_text.text = "%d / 30" % battle_opponent_hp
	battle_player_hp_bar.value = battle_player_hp
	battle_opponent_hp_bar.value = battle_opponent_hp
	battle_status.text = "能量  %d / 3     格挡  %d" % [battle_energy, battle_block]
	battle_deck_label.text = "你的手牌     %d 张在手  ·  牌库 %d  ·  弃牌 %d" % [battle_hand.size(), battle_deck.size(), battle_discard.size()]
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
			var category := "攻击"
			var accent := Color("#f87171")
			match card["type"]:
				"block":
					category = "防御"
					accent = Color("#5eead4")
				"disrupt":
					category = "干扰"
					accent = Color("#c4b5fd")
			button.text = "%s     %d 能量\n\n%s\n%s" % [category, card["cost"], card["name"], card["description"]]
			button.add_theme_color_override("font_color", Color("#dbe7f5"))
			button.add_theme_color_override("font_hover_color", Color.WHITE)
			button.add_theme_color_override("font_disabled_color", Color("#67748a"))
			button.add_theme_stylebox_override("normal", _battle_card_style(Color("#202c42"), Color(accent, 0.75)))
			button.add_theme_stylebox_override("hover", _battle_card_style(Color("#2a3a56"), accent))
			button.add_theme_stylebox_override("pressed", _battle_card_style(Color("#151f32"), accent))
			button.disabled = battle_finished or battle_energy < card["cost"]
		else:
			button.text = "待抽取"
			button.disabled = true

func _material(color: Color, emissive := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 0.5
	return material
