extends Node3D

const PLAYER_SPEED := 5.0
const INTERACTION_DISTANCE := 3.2
const PLAYER_MAX_HP := 30
const PLAYER_MAX_STAMINA := 100
const BATTLE_STAMINA_PER_TURN := 20
const XP_PER_LEVEL := 100
const BATTLE_VICTORY_XP := 25
const EQUIPMENT_SLOT_NAMES := {"weapon": "武器", "clothes": "衣服", "shoes": "鞋子", "hat": "帽子"}

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
var inventory_grid: GridContainer
var inventory_slots: Array[Button] = []
var inventory_feedback: Label
var equipment_button: Button
var equipment_panel: Panel
var equipment_summary: Label
var equipment_slot_widgets: Dictionary = {}
var talent_button: Button
var talent_panel: Panel
var talent_summary: Label
var talent_rows: VBoxContainer
var player_status_hud: Panel
var player_level_label: Label
var player_hp_label: Label
var player_hp_bar: ProgressBar
var player_hp_value: Label
var player_xp_label: Label
var player_xp_bar: ProgressBar
var player_xp_value: Label
var deck_view_button: Button
var deck_view_panel: Panel
var deck_view_title: Label
var deck_view_summary: Label
var deck_view_rows: VBoxContainer
var deck_theme_buttons: Dictionary = {}
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
var battle_title_label: Label
var battle_status: Label
var battle_intent: Label
var battle_feedback: Label
var battle_turn_label: Label
var battle_deck_label: Label
var battle_player_hp_bar: ProgressBar
var battle_opponent_hp_bar: ProgressBar
var battle_player_hp_text: Label
var battle_opponent_hp_text: Label
var battle_opponent_name_label: Label
var battle_stamina_bar: ProgressBar
var battle_stamina_text: Label
var battle_xp_bar: ProgressBar
var battle_xp_text: Label
var battle_cards_container: HBoxContainer
var battle_card_buttons: Array[Button] = []
var battle_card_widgets: Array[Dictionary] = []
var battle_pending_draw_indices: Array[int] = []
var battle_shuffle_pending := false
var battle_animation_layer: Control
var battle_end_button: Button
var battle_opponent: Node3D
var level_select_panel: Panel
var level_select_summary: Label
var level_select_buttons: Dictionary = {}
var level_deck_buttons: Dictionary = {}
var level_start_button: Button
var level_selected_id := "CH1-01"
var level_challenger: Node3D
var dialogue_index := 0
var dialogue_lines: Array[String] = []
var battle_player_hp := PLAYER_MAX_HP
var battle_opponent_hp := 30
var battle_opponent_max_hp := 30
var player_stamina := PLAYER_MAX_STAMINA
var player_xp := 0
var player_level := 1
var player_talent_points := 0
var unlocked_talents: Dictionary = {}
var battle_block := 0
var battle_turn := 1
var battle_weakens_opponent := false
var battle_finished := false
var battle_won := false
var battle_hand: Array[Dictionary] = []
var battle_deck: Array[String] = []
var battle_discard: Array[String] = []
var battle_next_action_damage_bonus := 0
var battle_feedback_text := ""
var current_level_id := "CH1-01"
var current_level: Dictionary = {}
var battle_intent_index := 0
var level_rewards_claimed: Dictionary = {}
var active_deck_id := "table_tennis"
var battle_decks := {
	"table_tennis": {"name": "乒乓球 · 近台快攻", "cards": ["tt_main", "tt_sub", "tt_control", "tt_defense", "tt_resource", "tt_tactic"]},
	"badminton": {"name": "羽毛球 · 杀上网", "cards": ["bad_main", "bad_sub", "bad_control", "bad_defense", "bad_resource", "bad_tactic"]},
	"tennis": {"name": "网球 · 底线相持", "cards": ["ten_main", "ten_sub", "ten_control", "ten_defense", "ten_resource", "ten_tactic"]}
}
var player_deck: Array[String] = ["tt_main", "tt_sub", "tt_control", "tt_defense", "tt_resource", "tt_tactic"]

var level_definitions := {
	"CH0-01": {
		"name": "发球机·初号", "type": "教学", "max_hp": 36, "reward_xp": 10,
		"intents": [
			{"name": "送球", "damage": 6}, {"name": "送球", "damage": 6}, {"name": "送球", "damage": 6}
		],
		"pre_battle": "训练协议：先观察意图，再安排出牌。", "defeat_hint": "教学关会重新开始。"
	},
	"CH0-B01": {
		"name": "裁判机器人", "type": "BOSS", "max_hp": 75, "reward_xp": 100,
		"intents": [
			{"name": "判定·警告", "damage": 10},
			{"name": "蓄力", "damage": 0, "charge": true, "next_damage": 18},
			{"name": "判定·罚分", "damage": 18}
		],
		"pre_battle": "它会先蓄力再重击。蓄力回合是抢输出还是先垫格挡？", "defeat_hint": "重击 18 点，一张格挡挡不住；试试牵制或在蓄力回合输出。"
	},
	"CH1-01": {
		"name": "陪练机器人", "type": "主线", "max_hp": 55, "reward_xp": 25,
		"intents": [
			{"name": "快带", "damage": 10}, {"name": "挡球", "damage": 8}, {"name": "挡球", "damage": 8}
		],
		"pre_battle": "节奏不快，但每一拍都在试你的体力分配。", "defeat_hint": "先看下一拍再决定出什么，格挡只在本回合有效。"
	},
	"CH1-E01": {
		"name": "破防型选手", "type": "精英", "max_hp": 70, "reward_xp": 60,
		"intents": [
			{"name": "试探", "damage": 8}, {"name": "破防", "damage": 14, "armor_break": true}, {"name": "追身", "damage": 8}
		],
		"pre_battle": "它有一拍能穿透防守。建议满血再来。", "defeat_hint": "破防那一下格挡没用，用牵制把它减半，或者换输出。"
	},
	"CH1-S01": {
		"name": "节奏控制器", "type": "支线", "max_hp": 65, "reward_xp": 40, "repeat_xp": 10, "first_items": {"med_patch": 2},
		"intents": [
			{"name": "重切", "damage": 12}, {"name": "搓短", "damage": 6},
			{"name": "拖慢", "damage": 6, "suppress_recovery": 10}
		],
		"pre_battle": "它会拖慢你的恢复节奏，别指望攒够一回合的体力。", "defeat_hint": "恢复被压低的回合，只出得起一张副攻或一张格挡。"
	}
}

var battle_card_definitions := {
	"tt_main": {"name": "正手冲球", "type": "action", "effect": "damage", "cost": 15, "value": 4, "description": "武器基础伤害 +4 招式伤害"},
	"tt_sub": {"name": "反手拧拉", "type": "action", "effect": "damage", "cost": 10, "value": 2, "description": "武器基础伤害 +2 招式伤害"},
	"tt_control": {"name": "侧身暴冲", "type": "action", "effect": "disrupt", "cost": 15, "value": 1, "description": "武器基础伤害 +1，并使敌方本回合攻击减半"},
	"tt_defense": {"name": "削球", "type": "defense", "effect": "block", "cost": 10, "value": 7, "description": "获得 7 点格挡"},
	"tt_resource": {"name": "摆短", "type": "resource", "effect": "draw", "cost": 5, "value": 1, "description": "抽 1 张牌"},
	"tt_tactic": {"name": "霸王拧", "type": "tactic", "effect": "next_action_bonus", "cost": 5, "value": 3, "description": "下一张行动牌伤害 +3"},
	"bad_main": {"name": "重杀", "type": "action", "effect": "damage", "cost": 15, "value": 4, "description": "武器基础伤害 +4 招式伤害"},
	"bad_sub": {"name": "劈吊", "type": "action", "effect": "damage", "cost": 10, "value": 2, "description": "武器基础伤害 +2 招式伤害"},
	"bad_control": {"name": "平抽挡", "type": "action", "effect": "disrupt", "cost": 15, "value": 1, "description": "武器基础伤害 +1，并使敌方本回合攻击减半"},
	"bad_defense": {"name": "挡网", "type": "defense", "effect": "block", "cost": 10, "value": 7, "description": "获得 7 点格挡"},
	"bad_resource": {"name": "搓球", "type": "resource", "effect": "draw", "cost": 5, "value": 1, "description": "抽 1 张牌"},
	"bad_tactic": {"name": "起跳杀", "type": "tactic", "effect": "next_action_bonus", "cost": 5, "value": 3, "description": "下一张行动牌伤害 +3"},
	"ten_main": {"name": "正手平击", "type": "action", "effect": "damage", "cost": 15, "value": 4, "description": "武器基础伤害 +4 招式伤害"},
	"ten_sub": {"name": "双手反拍", "type": "action", "effect": "damage", "cost": 10, "value": 2, "description": "武器基础伤害 +2 招式伤害"},
	"ten_control": {"name": "放短球", "type": "action", "effect": "disrupt", "cost": 15, "value": 1, "description": "武器基础伤害 +1，并使敌方本回合攻击减半"},
	"ten_defense": {"name": "切削球", "type": "defense", "effect": "block", "cost": 10, "value": 7, "description": "获得 7 点格挡"},
	"ten_resource": {"name": "挑高球", "type": "resource", "effect": "draw", "cost": 5, "value": 1, "description": "抽 1 张牌"},
	"ten_tactic": {"name": "高压球", "type": "tactic", "effect": "next_action_bonus", "cost": 5, "value": 3, "description": "下一张行动牌伤害 +3"}
}
var equipment_slots := {"weapon": "starter_racket", "clothes": "", "shoes": "", "hat": ""}
var equipment_definitions := {
	"starter_racket": {"name": "训练球拍", "slot": "weapon", "base_damage": 4, "description": "主角的基础武器，提供 4 点基础伤害。"}
}
var talent_order: Array[String] = ["racket_calibration", "read_intent", "field_routine", "tactical_memory"]
var talent_definitions := {
	"racket_calibration": {"name": "拍面校准", "branch": "战斗", "cost": 1, "requires": [], "effect": "action_damage_bonus", "value": 1, "description": "攻击和干扰行动牌伤害 +1。"},
	"read_intent": {"name": "意图预判", "branch": "战斗", "cost": 1, "requires": ["racket_calibration"], "effect": "start_block", "value": 2, "description": "每场牌战开始时获得 2 点格挡。"},
	"field_routine": {"name": "现场急救", "branch": "生存", "cost": 1, "requires": [], "effect": "heal_bonus", "value": 2, "description": "战斗外使用治疗物品时额外恢复 2 点生命。"},
	"tactical_memory": {"name": "战术记忆", "branch": "战术", "cost": 1, "requires": ["read_intent"], "effect": "tactic_bonus", "value": 1, "description": "战术增幅使下一张行动牌额外 +1 伤害。"}
}
var money := 120
var inventory := {
	"energy_drink": 1,
	"med_patch": 1,
	"trauma_kit": 0,
	"data_chip": 0,
	"repair_kit": 1
}

var shop_items := [
	{"id": "energy_drink", "name": "能量饮料", "buy": 20, "sell": 10, "description": "恢复 6 点生命值的便携饮品", "effect": "heal", "value": 6, "color": Color("#fb7185")},
	{"id": "med_patch", "name": "急救贴", "buy": 32, "sell": 16, "description": "恢复 10 点生命值", "effect": "heal", "value": 10, "color": Color("#f97316")},
	{"id": "trauma_kit", "name": "创伤包", "buy": 58, "sell": 29, "description": "恢复 18 点生命值", "effect": "heal", "value": 18, "color": Color("#ef4444")},
	{"id": "data_chip", "name": "数据芯片", "buy": 35, "sell": 18, "description": "存有城市接口资料", "effect": "none", "value": 0, "color": Color("#60a5fa")},
	{"id": "repair_kit", "name": "维修工具包", "buy": 28, "sell": 14, "description": "常见设备维修材料", "effect": "none", "value": 0, "color": Color("#fbbf24")}
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
		"level_id": "CH0-01",
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
			elif level_select_panel != null and level_select_panel.visible:
				_close_level_select()
			elif equipment_panel != null and equipment_panel.visible:
				equipment_panel.visible = false
			elif talent_panel != null and talent_panel.visible:
				talent_panel.visible = false
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
		if data.has("level_id"):
			npc.set_meta("level_id", data["level_id"])
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
	_setup_player_status_hud(layer)

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
	economy_hud.position = Vector2(900, 32)
	economy_hud.size = Vector2(350, 474)
	var hud_style := StyleBoxFlat.new()
	hud_style.bg_color = Color(0.025, 0.06, 0.11, 0.88)
	hud_style.border_color = Color("#47718c")
	hud_style.set_border_width_all(1)
	hud_style.set_corner_radius_all(8)
	economy_hud.add_theme_stylebox_override("panel", hud_style)
	layer.add_child(economy_hud)

	economy_text = Label.new()
	economy_text.position = Vector2(16, 12)
	economy_text.size = Vector2(318, 44)
	economy_text.add_theme_font_size_override("font_size", 16)
	economy_text.add_theme_color_override("font_color", Color("#edf7ff"))
	economy_hud.add_child(economy_text)

	inventory_grid = GridContainer.new()
	inventory_grid.position = Vector2(14, 66)
	inventory_grid.size = Vector2(322, 220)
	inventory_grid.columns = 3
	inventory_grid.add_theme_constant_override("h_separation", 8)
	inventory_grid.add_theme_constant_override("v_separation", 8)
	economy_hud.add_child(inventory_grid)
	for item_index in range(9):
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(102, 68)
		slot.add_theme_font_size_override("font_size", 13)
		slot.add_theme_color_override("font_color", Color("#edf7ff"))
		slot.add_theme_color_override("font_disabled_color", Color("#697887"))
		slot.add_theme_stylebox_override("normal", _make_inventory_slot_style(Color("#172635"), Color("#31495c")))
		slot.add_theme_stylebox_override("hover", _make_inventory_slot_style(Color("#20394b"), Color("#56b6bd")))
		slot.add_theme_stylebox_override("pressed", _make_inventory_slot_style(Color("#254455"), Color("#78d6d2")))
		slot.add_theme_stylebox_override("disabled", _make_inventory_slot_style(Color("#111a23"), Color("#24313b")))
		inventory_grid.add_child(slot)
		inventory_slots.append(slot)
		if item_index < shop_items.size():
			slot.pressed.connect(_use_item.bind(shop_items[item_index]["id"]))
		slot.disabled = true

	inventory_feedback = Label.new()
	inventory_feedback.position = Vector2(16, 294)
	inventory_feedback.size = Vector2(318, 46)
	inventory_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inventory_feedback.add_theme_font_size_override("font_size", 14)
	inventory_feedback.add_theme_color_override("font_color", Color("#a9bfd1"))
	inventory_feedback.text = "医疗用品可在牌战外使用"
	economy_hud.add_child(inventory_feedback)

	deck_view_button = Button.new()
	deck_view_button.position = Vector2(16, 366)
	deck_view_button.size = Vector2(102, 42)
	deck_view_button.text = "牌组"
	deck_view_button.add_theme_font_size_override("font_size", 16)
	deck_view_button.pressed.connect(_open_deck_view)
	economy_hud.add_child(deck_view_button)
	codex_button = Button.new()
	codex_button.position = Vector2(124, 366)
	codex_button.size = Vector2(102, 42)
	codex_button.text = "图鉴"
	codex_button.add_theme_font_size_override("font_size", 16)
	codex_button.pressed.connect(_open_codex)
	economy_hud.add_child(codex_button)
	equipment_button = Button.new()
	equipment_button.position = Vector2(244, 366)
	equipment_button.size = Vector2(90, 42)
	equipment_button.text = "装备"
	equipment_button.add_theme_font_size_override("font_size", 16)
	equipment_button.pressed.connect(_open_equipment)
	economy_hud.add_child(equipment_button)
	talent_button = Button.new()
	talent_button.position = Vector2(16, 414)
	talent_button.size = Vector2(318, 42)
	talent_button.text = "天赋  ·  %d 点可用" % player_talent_points
	talent_button.add_theme_font_size_override("font_size", 16)
	talent_button.pressed.connect(_open_talent)
	economy_hud.add_child(talent_button)

	shop_panel = Panel.new()
	shop_panel.position = Vector2(60, 150)
	shop_panel.size = Vector2(1160, 500)
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
	columns.size = Vector2(1110, 350)
	columns.add_theme_constant_override("separation", 24)
	shop_panel.add_child(columns)

	shop_rows = VBoxContainer.new()
	shop_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_rows.add_theme_constant_override("separation", 8)
	columns.add_child(shop_rows)

	shop_feedback = Label.new()
	shop_feedback.position = Vector2(24, 430)
	shop_feedback.size = Vector2(850, 34)
	shop_feedback.add_theme_font_size_override("font_size", 18)
	shop_feedback.add_theme_color_override("font_color", Color("#9ee8d7"))
	shop_panel.add_child(shop_feedback)

	var close_hint := Label.new()
	close_hint.position = Vector2(900, 430)
	close_hint.size = Vector2(230, 34)
	close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	close_hint.text = "[Esc] 关闭商店"
	close_hint.add_theme_font_size_override("font_size", 18)
	close_hint.add_theme_color_override("font_color", Color("#a9bfd1"))
	shop_panel.add_child(close_hint)
	_setup_deck_and_codex_ui(layer)
	_setup_equipment_ui(layer)
	_setup_talent_ui(layer)
	_setup_battle_ui(layer)
	_setup_level_select_ui(layer)

	_refresh_economy_hud()
	_refresh_inventory_grid()
	_refresh_player_status_hud()

func _setup_level_select_ui(layer: CanvasLayer) -> void:
	level_select_panel = Panel.new()
	level_select_panel.position = Vector2(64, 72)
	level_select_panel.size = Vector2(1152, 576)
	level_select_panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#101827")
	style.border_color = Color("#58b4bd")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	level_select_panel.add_theme_stylebox_override("panel", style)
	layer.add_child(level_select_panel)

	var title := Label.new()
	title.position = Vector2(28, 20)
	title.size = Vector2(700, 36)
	title.text = "训练中心  /  选择挑战"
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color("#d8f4f3"))
	level_select_panel.add_child(title)

	var subtitle := Label.new()
	subtitle.position = Vector2(28, 60)
	subtitle.size = Vector2(700, 24)
	subtitle.text = "固定意图循环 · 可在挑战前切换主题牌组"
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color("#9aafbf"))
	level_select_panel.add_child(subtitle)

	var list := VBoxContainer.new()
	list.position = Vector2(28, 106)
	list.size = Vector2(330, 380)
	list.add_theme_constant_override("separation", 10)
	level_select_panel.add_child(list)
	for level_id in level_definitions:
		var level: Dictionary = level_definitions[level_id]
		var button := Button.new()
		button.custom_minimum_size = Vector2(320, 60)
		button.text = "%s  ·  %s" % [level["type"], level["name"]]
		button.add_theme_font_size_override("font_size", 17)
		button.pressed.connect(_select_level.bind(level_id))
		list.add_child(button)
		level_select_buttons[level_id] = button

	level_select_summary = Label.new()
	level_select_summary.position = Vector2(390, 108)
	level_select_summary.size = Vector2(700, 160)
	level_select_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	level_select_summary.add_theme_font_size_override("font_size", 19)
	level_select_summary.add_theme_color_override("font_color", Color("#e3edf5"))
	level_select_panel.add_child(level_select_summary)

	var deck_label := Label.new()
	deck_label.position = Vector2(390, 290)
	deck_label.text = "出战牌组"
	deck_label.add_theme_font_size_override("font_size", 16)
	deck_label.add_theme_color_override("font_color", Color("#9aafbf"))
	level_select_panel.add_child(deck_label)
	var deck_row := HBoxContainer.new()
	deck_row.position = Vector2(390, 320)
	deck_row.size = Vector2(700, 50)
	deck_row.add_theme_constant_override("separation", 10)
	level_select_panel.add_child(deck_row)
	for deck_id in battle_decks:
		var button := Button.new()
		button.custom_minimum_size = Vector2(210, 44)
		button.text = battle_decks[deck_id]["name"]
		button.pressed.connect(_select_level_deck.bind(deck_id))
		deck_row.add_child(button)
		level_deck_buttons[deck_id] = button

	level_start_button = Button.new()
	level_start_button.position = Vector2(830, 476)
	level_start_button.size = Vector2(260, 54)
	level_start_button.text = "开始挑战"
	level_start_button.add_theme_font_size_override("font_size", 19)
	level_start_button.pressed.connect(_start_selected_level)
	level_select_panel.add_child(level_start_button)

	var cancel_button := Button.new()
	cancel_button.position = Vector2(390, 476)
	cancel_button.size = Vector2(180, 54)
	cancel_button.text = "返回探索  [Esc]"
	cancel_button.pressed.connect(_close_level_select)
	level_select_panel.add_child(cancel_button)
	_select_level(level_selected_id)
	_refresh_level_deck_buttons()

func _setup_player_status_hud(layer: CanvasLayer) -> void:
	player_status_hud = Panel.new()
	player_status_hud.position = Vector2(40, 88)
	player_status_hud.size = Vector2(300, 96)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.045, 0.07, 0.78)
	panel_style.border_color = Color("#34495c")
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(5)
	player_status_hud.add_theme_stylebox_override("panel", panel_style)
	layer.add_child(player_status_hud)

	var title := _make_status_label(Vector2(14, 8), Vector2(160, 18), Color("#d8e3ec"))
	title.text = "角色状态"
	title.add_theme_font_size_override("font_size", 13)
	player_status_hud.add_child(title)
	player_level_label = _make_status_label(Vector2(210, 8), Vector2(76, 18), Color("#b9c7d2"))
	player_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	player_level_label.add_theme_font_size_override("font_size", 12)
	player_status_hud.add_child(player_level_label)

	player_hp_label = _make_status_label(Vector2(14, 34), Vector2(52, 18), Color("#fb8290"))
	player_status_hud.add_child(player_hp_label)
	player_hp_bar = _make_status_bar(PLAYER_MAX_HP, Color("#fb7185"))
	player_hp_bar.position = Vector2(72, 39)
	player_hp_bar.size = Vector2(132, 9)
	player_status_hud.add_child(player_hp_bar)
	player_hp_value = _make_status_label(Vector2(212, 34), Vector2(74, 18), Color("#e3eaf0"))
	player_hp_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	player_hp_value.add_theme_font_size_override("font_size", 12)
	player_status_hud.add_child(player_hp_value)

	player_xp_label = _make_status_label(Vector2(14, 60), Vector2(52, 18), Color("#f3c96b"))
	player_status_hud.add_child(player_xp_label)
	player_xp_bar = _make_status_bar(XP_PER_LEVEL, Color("#fbbf24"))
	player_xp_bar.position = Vector2(72, 65)
	player_xp_bar.size = Vector2(132, 9)
	player_status_hud.add_child(player_xp_bar)
	player_xp_value = _make_status_label(Vector2(212, 60), Vector2(74, 18), Color("#e3eaf0"))
	player_xp_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	player_xp_value.add_theme_font_size_override("font_size", 12)
	player_status_hud.add_child(player_xp_value)

func _make_status_label(position: Vector2, size: Vector2, color: Color) -> Label:
	var label := Label.new()
	label.position = position
	label.size = size
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", color)
	return label

func _make_status_bar(max_value: int, fill_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = max_value
	bar.show_percentage = false
	var background := StyleBoxFlat.new()
	background.bg_color = Color("#25313b")
	background.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	return bar

func _make_inventory_slot_style(fill_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 3
	style.content_margin_right = 3
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style

func _refresh_player_status_hud() -> void:
	if player_hp_label == null:
		return
	player_level_label.text = "等级  %02d" % player_level
	player_hp_label.text = "生命"
	player_hp_label.tooltip_text = "当前生命值"
	player_hp_bar.value = battle_player_hp
	player_hp_value.text = "%d / %d" % [battle_player_hp, PLAYER_MAX_HP]
	player_xp_label.text = "经验"
	player_xp_label.tooltip_text = "升级经验进度"
	player_xp_bar.value = player_xp
	player_xp_value.text = "%d / %d" % [player_xp, XP_PER_LEVEL]
	if talent_button != null:
		talent_button.text = "天赋  ·  %d 点可用" % player_talent_points

func _grant_battle_victory_xp() -> void:
	var first_clear: bool = not bool(level_rewards_claimed.get(current_level_id, false))
	var reward_xp := int(current_level.get("reward_xp", BATTLE_VICTORY_XP)) if first_clear else int(current_level.get("repeat_xp", BATTLE_VICTORY_XP))
	player_xp += reward_xp
	level_rewards_claimed[current_level_id] = true
	if first_clear:
		for item_id in current_level.get("first_items", {}):
			inventory[item_id] = int(inventory.get(item_id, 0)) + int(current_level["first_items"][item_id])
	while player_xp >= XP_PER_LEVEL:
		player_xp -= XP_PER_LEVEL
		player_level += 1
		player_talent_points += 1
	_refresh_player_status_hud()
	_refresh_talent()
	_refresh_inventory_grid()
	battle_feedback_text = "你赢下了「%s」，获得 %d 点经验。" % [current_level.get("name", "牌战"), reward_xp]

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
	var theme_options := ["table_tennis", "badminton", "tennis"]
	var theme_labels := ["乒乓球", "羽毛球", "网球"]
	for index in range(theme_options.size()):
		var deck_id: String = theme_options[index]
		var theme_button := Button.new()
		theme_button.position = Vector2(30 + index * 208, 100)
		theme_button.size = Vector2(196, 38)
		theme_button.text = theme_labels[index]
		theme_button.pressed.connect(_select_deck.bind(deck_id))
		deck_view_panel.add_child(theme_button)
		deck_theme_buttons[deck_id] = theme_button
	deck_view_rows = VBoxContainer.new()
	deck_view_rows.position = Vector2(30, 148)
	deck_view_rows.size = Vector2(640, 294)
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

func _setup_equipment_ui(layer: CanvasLayer) -> void:
	equipment_panel = _make_collection_panel(Vector2(330, 112), Vector2(620, 472), Color("#e5aa52"))
	equipment_panel.visible = false
	layer.add_child(equipment_panel)
	var title := _make_collection_title("角色装备", Color("#ffd166"))
	equipment_panel.add_child(title)
	equipment_summary = Label.new()
	equipment_summary.position = Vector2(30, 64)
	equipment_summary.size = Vector2(550, 32)
	equipment_summary.add_theme_font_size_override("font_size", 16)
	equipment_summary.add_theme_color_override("font_color", Color("#c8d5e4"))
	equipment_panel.add_child(equipment_summary)
	for slot_id in EQUIPMENT_SLOT_NAMES:
		var slot_panel := Panel.new()
		slot_panel.position = Vector2(30, 112 + equipment_slot_widgets.size() * 72)
		slot_panel.size = Vector2(560, 60)
		var slot_style := StyleBoxFlat.new()
		slot_style.bg_color = Color("#151e30")
		slot_style.border_color = Color("#3a4c60")
		slot_style.set_border_width_all(1)
		slot_style.set_corner_radius_all(6)
		slot_panel.add_theme_stylebox_override("panel", slot_style)
		var slot_label := Label.new()
		slot_label.position = Vector2(14, 17)
		slot_label.size = Vector2(100, 26)
		slot_label.text = EQUIPMENT_SLOT_NAMES[slot_id]
		slot_label.add_theme_font_size_override("font_size", 17)
		slot_label.add_theme_color_override("font_color", Color("#9fb2c7"))
		slot_panel.add_child(slot_label)
		var item_label := Label.new()
		item_label.position = Vector2(126, 12)
		item_label.size = Vector2(410, 36)
		item_label.add_theme_font_size_override("font_size", 17)
		item_label.add_theme_color_override("font_color", Color("#f1f5f9"))
		slot_panel.add_child(item_label)
		equipment_panel.add_child(slot_panel)
		equipment_slot_widgets[slot_id] = item_label
	var close_button := _make_collection_close_button()
	close_button.pressed.connect(func(): equipment_panel.visible = false)
	equipment_panel.add_child(close_button)
	_refresh_equipment_ui()

func _open_equipment() -> void:
	if battle_panel != null and battle_panel.visible:
		return
	deck_view_panel.visible = false
	codex_panel.visible = false
	_refresh_equipment_ui()
	equipment_panel.visible = true

func _refresh_equipment_ui() -> void:
	if equipment_summary == null:
		return
	var weapon_base_damage := _get_weapon_base_damage()
	equipment_summary.text = "当前武器基础伤害 %d  ·  攻击牌伤害 = 武器基础 + 招式加成" % weapon_base_damage
	for slot_id in EQUIPMENT_SLOT_NAMES:
		var item_id: String = equipment_slots.get(slot_id, "")
		var item_label: Label = equipment_slot_widgets[slot_id]
		if item_id.is_empty() or not equipment_definitions.has(item_id):
			item_label.text = "未装备"
			item_label.add_theme_color_override("font_color", Color("#78899b"))
			continue
		var item: Dictionary = equipment_definitions[item_id]
		var item_text := String(item["name"])
		if slot_id == "weapon":
			item_text += "    基础伤害 %d" % int(item.get("base_damage", 0))
		item_label.text = item_text
		item_label.add_theme_color_override("font_color", Color("#f1f5f9"))

func _get_weapon_base_damage() -> int:
	var weapon_id: String = equipment_slots.get("weapon", "")
	if weapon_id.is_empty() or not equipment_definitions.has(weapon_id):
		return 0
	return int(equipment_definitions[weapon_id].get("base_damage", 0))

func _setup_talent_ui(layer: CanvasLayer) -> void:
	talent_panel = _make_collection_panel(Vector2(245, 70), Vector2(760, 560), Color("#8b9cf6"))
	talent_panel.visible = false
	layer.add_child(talent_panel)
	var title := _make_collection_title("天赋", Color("#c4b5fd"))
	talent_panel.add_child(title)
	talent_summary = Label.new()
	talent_summary.position = Vector2(30, 64)
	talent_summary.size = Vector2(700, 32)
	talent_summary.add_theme_font_size_override("font_size", 17)
	talent_summary.add_theme_color_override("font_color", Color("#c8d5e4"))
	talent_panel.add_child(talent_summary)
	talent_rows = VBoxContainer.new()
	talent_rows.position = Vector2(30, 112)
	talent_rows.size = Vector2(700, 330)
	talent_rows.add_theme_constant_override("separation", 10)
	talent_panel.add_child(talent_rows)
	var hint := Label.new()
	hint.position = Vector2(30, 458)
	hint.size = Vector2(700, 28)
	hint.text = "升级获得天赋点；节点必须满足前置条件后才能解锁。"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color("#8fa3b8"))
	talent_panel.add_child(hint)
	var close_button := _make_collection_close_button()
	close_button.position = Vector2(570, 500)
	close_button.pressed.connect(func(): talent_panel.visible = false)
	talent_panel.add_child(close_button)
	_refresh_talent()

func _open_talent() -> void:
	if battle_panel != null and battle_panel.visible:
		return
	deck_view_panel.visible = false
	codex_panel.visible = false
	equipment_panel.visible = false
	_refresh_talent()
	talent_panel.visible = true

func _refresh_talent() -> void:
	if talent_rows == null:
		return
	_clear_collection_rows(talent_rows)
	talent_summary.text = "可用天赋点：%d  ·  已解锁：%d / %d" % [player_talent_points, unlocked_talents.size(), talent_definitions_count()]
	for talent_id in talent_order:
		var talent: Dictionary = talent_definitions[talent_id]
		var row := Panel.new()
		row.custom_minimum_size = Vector2(700, 72)
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#151e30") if _talent_is_unlocked(talent_id) else Color("#101827")
		style.border_color = Color("#9b8ff5") if _talent_is_unlocked(talent_id) else Color("#35445b")
		style.set_border_width_all(1)
		style.set_corner_radius_all(7)
		row.add_theme_stylebox_override("panel", style)
		var name_label := Label.new()
		name_label.position = Vector2(16, 10)
		name_label.size = Vector2(270, 25)
		name_label.text = "%s  ·  %s" % [talent["name"], talent["branch"]]
		name_label.add_theme_font_size_override("font_size", 17)
		name_label.add_theme_color_override("font_color", Color("#f1f5f9"))
		row.add_child(name_label)
		var description := Label.new()
		description.position = Vector2(16, 38)
		description.size = Vector2(490, 25)
		description.text = _talent_description_with_prerequisites(talent_id)
		description.add_theme_font_size_override("font_size", 14)
		description.add_theme_color_override("font_color", Color("#aebbd0"))
		row.add_child(description)
		var unlock_button := Button.new()
		unlock_button.position = Vector2(540, 17)
		unlock_button.size = Vector2(142, 38)
		unlock_button.add_theme_font_size_override("font_size", 14)
		if _talent_is_unlocked(talent_id):
			unlock_button.text = "已解锁"
			unlock_button.disabled = true
		elif _can_unlock_talent(talent_id):
			unlock_button.text = "解锁  ·  %d 点" % int(talent["cost"])
			unlock_button.pressed.connect(_unlock_talent.bind(talent_id))
		else:
			unlock_button.text = "需要前置"
			unlock_button.disabled = true
		row.add_child(unlock_button)
		talent_rows.add_child(row)
	if talent_button != null:
		talent_button.text = "天赋  ·  %d 点可用" % player_talent_points

func talent_definitions_count() -> int:
	return talent_definitions.size()

func _talent_is_unlocked(talent_id: String) -> bool:
	return unlocked_talents.get(talent_id, false)

func _can_unlock_talent(talent_id: String) -> bool:
	if not talent_definitions.has(talent_id) or _talent_is_unlocked(talent_id):
		return false
	var talent: Dictionary = talent_definitions[talent_id]
	if player_talent_points < int(talent["cost"]):
		return false
	for required_id in talent["requires"]:
		if not _talent_is_unlocked(required_id):
			return false
	return true

func _unlock_talent(talent_id: String) -> void:
	if not _can_unlock_talent(talent_id):
		return
	var talent: Dictionary = talent_definitions[talent_id]
	player_talent_points -= int(talent["cost"])
	unlocked_talents[talent_id] = true
	_refresh_talent()
	_refresh_player_status_hud()

func _talent_description_with_prerequisites(talent_id: String) -> String:
	var talent: Dictionary = talent_definitions[talent_id]
	var requirements: Array = talent["requires"]
	if requirements.is_empty():
		return String(talent["description"])
	var names: Array[String] = []
	for required_id in requirements:
		names.append(String(talent_definitions[required_id]["name"]))
	return "%s  ·  前置：%s" % [talent["description"], "、".join(names)]

func _get_talent_bonus(effect: String) -> int:
	var total := 0
	for talent_id in unlocked_talents:
		var talent: Dictionary = talent_definitions.get(talent_id, {})
		if talent.get("effect", "") == effect:
			total += int(talent.get("value", 0))
	return total

func _card_display_description(card: Dictionary) -> String:
	var effect := String(card.get("effect", ""))
	if String(card.get("type", "")) == "action" and effect in ["damage", "disrupt"]:
		return "%s  ·  总伤害 %d" % [card["description"], _get_weapon_base_damage() + int(card["value"]) + _get_talent_bonus("action_damage_bonus")]
	return String(card["description"])

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
	deck_view_summary.text = "%s  ·  共 %d 张" % [battle_decks[active_deck_id]["name"], player_deck.size()]
	for deck_id in deck_theme_buttons:
		var theme_button: Button = deck_theme_buttons[deck_id]
		theme_button.disabled = deck_id == active_deck_id
	for card_id in battle_card_definitions:
		var count: int = player_deck.count(card_id)
		if count <= 0:
			continue
		deck_view_rows.add_child(_make_collection_card_row(card_id, "%d 张" % count))

func _select_deck(deck_id: String) -> void:
	if not battle_decks.has(deck_id):
		return
	active_deck_id = deck_id
	player_deck.clear()
	for card_id in battle_decks[deck_id]["cards"]:
		player_deck.append(String(card_id))
	_refresh_deck_view()

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
	name_label.text = "%s  ·  费用 %d" % [card["name"], int(card["cost"])]
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color", Color("#f1f5f9"))
	row.add_child(name_label)
	var description := Label.new()
	description.position = Vector2(98, 38)
	description.size = Vector2(420, 22)
	description.text = _card_display_description(card)
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

	battle_title_label = Label.new()
	battle_title_label.position = Vector2(32, 18)
	battle_title_label.size = Vector2(650, 30)
	battle_title_label.text = "STRATEGY CLUB  //  牌战协议"
	battle_title_label.add_theme_font_size_override("font_size", 16)
	battle_title_label.add_theme_color_override("font_color", Color("#a99cf2"))
	battle_panel.add_child(battle_title_label)

	battle_turn_label = Label.new()
	battle_turn_label.position = Vector2(870, 18)
	battle_turn_label.size = Vector2(290, 30)
	battle_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	battle_turn_label.text = "DUEL  01"
	battle_turn_label.add_theme_font_size_override("font_size", 16)
	battle_turn_label.add_theme_color_override("font_color", Color("#c4b5fd"))
	battle_panel.add_child(battle_turn_label)

	var player_status := _make_battle_status_panel(Vector2(32, 62), Vector2(540, 106), Color("#1d827d"))
	battle_panel.add_child(player_status)
	var player_name := Label.new()
	player_name.position = Vector2(18, 6)
	player_name.text = "你  /  PLAYER"
	player_name.add_theme_font_size_override("font_size", 17)
	player_name.add_theme_color_override("font_color", Color("#99f6e4"))
	player_status.add_child(player_name)
	battle_player_hp_text = Label.new()
	battle_player_hp_text.position = Vector2(430, 6)
	battle_player_hp_text.size = Vector2(90, 26)
	battle_player_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	battle_player_hp_text.add_theme_font_size_override("font_size", 17)
	battle_player_hp_text.add_theme_color_override("font_color", Color("#e6fffb"))
	player_status.add_child(battle_player_hp_text)
	battle_player_hp_bar = _make_battle_hp_bar(Color("#35d0c2"))
	battle_player_hp_bar.position = Vector2(18, 31)
	battle_player_hp_bar.size = Vector2(504, 14)
	player_status.add_child(battle_player_hp_bar)
	battle_stamina_text = _make_status_label(Vector2(430, 48), Vector2(90, 17), Color("#bfdbfe"))
	battle_stamina_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	battle_stamina_text.add_theme_font_size_override("font_size", 12)
	player_status.add_child(battle_stamina_text)
	var battle_stamina_label := _make_status_label(Vector2(18, 48), Vector2(100, 17), Color("#93c5fd"))
	battle_stamina_label.text = "体力"
	battle_stamina_label.add_theme_font_size_override("font_size", 12)
	player_status.add_child(battle_stamina_label)
	battle_stamina_bar = _make_status_bar(PLAYER_MAX_STAMINA, Color("#60a5fa"))
	battle_stamina_bar.position = Vector2(18, 65)
	battle_stamina_bar.size = Vector2(504, 9)
	player_status.add_child(battle_stamina_bar)
	battle_xp_text = _make_status_label(Vector2(430, 77), Vector2(90, 17), Color("#fde68a"))
	battle_xp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	battle_xp_text.add_theme_font_size_override("font_size", 12)
	player_status.add_child(battle_xp_text)
	var battle_xp_label := _make_status_label(Vector2(18, 77), Vector2(100, 17), Color("#fde68a"))
	battle_xp_label.text = "经验  Lv.%d" % player_level
	battle_xp_label.add_theme_font_size_override("font_size", 12)
	player_status.add_child(battle_xp_label)
	battle_xp_bar = _make_status_bar(XP_PER_LEVEL, Color("#fbbf24"))
	battle_xp_bar.position = Vector2(18, 94)
	battle_xp_bar.size = Vector2(504, 9)
	player_status.add_child(battle_xp_bar)

	var opponent_status := _make_battle_status_panel(Vector2(620, 62), Vector2(540, 94), Color("#7c54b5"))
	battle_panel.add_child(opponent_status)
	battle_opponent_name_label = Label.new()
	battle_opponent_name_label.position = Vector2(18, 10)
	battle_opponent_name_label.text = "对手"
	battle_opponent_name_label.add_theme_font_size_override("font_size", 17)
	battle_opponent_name_label.add_theme_color_override("font_color", Color("#ddd6fe"))
	opponent_status.add_child(battle_opponent_name_label)
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
		_open_level_select(npc)
	else:
		_open_or_advance_dialogue(npc)

func _open_level_select(npc: Node3D) -> void:
	level_challenger = npc
	level_selected_id = String(npc.get_meta("level_id", "CH1-01"))
	_select_level(level_selected_id)
	_refresh_level_deck_buttons()
	level_select_panel.visible = true

func _close_level_select() -> void:
	level_select_panel.visible = false
	level_challenger = null

func _select_level(level_id: String) -> void:
	if not level_definitions.has(level_id):
		return
	level_selected_id = level_id
	var level: Dictionary = level_definitions[level_id]
	var intent_text := ""
	for intent in level["intents"]:
		if not intent_text.is_empty():
			intent_text += " → "
		intent_text += "%s %d" % [intent["name"], int(intent["damage"])]
	level_select_summary.text = "%s\n生命 %d   ·   目标 %s\n意图循环：%s\n\n战前提示：%s" % [level["name"], int(level["max_hp"]), level["type"], intent_text, level["pre_battle"]]
	for id in level_select_buttons:
		var button: Button = level_select_buttons[id]
		button.modulate = Color("#7fe4dd") if id == level_id else Color.WHITE

func _select_level_deck(deck_id: String) -> void:
	if not battle_decks.has(deck_id):
		return
	active_deck_id = deck_id
	player_deck = battle_decks[deck_id]["cards"].duplicate()
	_refresh_level_deck_buttons()

func _refresh_level_deck_buttons() -> void:
	for deck_id in level_deck_buttons:
		var button: Button = level_deck_buttons[deck_id]
		button.modulate = Color("#7fe4dd") if deck_id == active_deck_id else Color.WHITE

func _start_selected_level() -> void:
	if level_challenger == null:
		return
	var challenger := level_challenger
	_close_level_select()
	_start_battle(challenger, level_selected_id)

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
	return (dialogue_panel != null and dialogue_panel.visible) or (shop_panel != null and shop_panel.visible) or (battle_panel != null and battle_panel.visible) or (level_select_panel != null and level_select_panel.visible) or (deck_view_panel != null and deck_view_panel.visible) or (codex_panel != null and codex_panel.visible) or (equipment_panel != null and equipment_panel.visible) or (talent_panel != null and talent_panel.visible)

func _enter_gate() -> void:
	var error := get_tree().change_scene_to_file("res://TransitRoom.tscn")
	if error != OK:
		interaction_hint.text = "无法载入目的地：%s" % error

func _toggle_inventory() -> void:
	if economy_hud.visible:
		deck_view_panel.visible = false
		codex_panel.visible = false
		equipment_panel.visible = false
		talent_panel.visible = false
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
	var occupied_slots := 0
	for item in shop_items:
		if inventory.get(item["id"], 0) > 0:
			occupied_slots += 1
	economy_text.text = "背包  [I]  ·  %d / 9 格\n信用点  %d" % [occupied_slots, money]

func _refresh_inventory_grid() -> void:
	if inventory_grid == null:
		return
	for index in range(inventory_slots.size()):
		var slot := inventory_slots[index]
		if index >= shop_items.size():
			slot.text = "空格"
			slot.tooltip_text = "空背包格"
			slot.disabled = true
			continue
		var item: Dictionary = shop_items[index]
		var count: int = inventory.get(item["id"], 0)
		if count <= 0:
			slot.text = "空格"
			slot.tooltip_text = "空背包格"
			slot.disabled = true
			slot.add_theme_stylebox_override("normal", _make_inventory_slot_style(Color("#111a23"), Color("#24313b")))
			slot.add_theme_stylebox_override("disabled", _make_inventory_slot_style(Color("#111a23"), Color("#24313b")))
			continue
		var effect_text := "+%d 生命" % item["value"] if item["effect"] == "heal" else "任务物品"
		slot.text = "%s\n×%d  ·  %s" % [item["name"], count, effect_text]
		slot.tooltip_text = "%s\n%s" % [item["name"], item["description"]]
		slot.disabled = false
		slot.add_theme_stylebox_override("normal", _make_inventory_slot_style(Color("#172635"), item["color"]))
		slot.add_theme_stylebox_override("hover", _make_inventory_slot_style(Color("#20394b"), item["color"].lightened(0.25)))
		slot.add_theme_stylebox_override("pressed", _make_inventory_slot_style(Color("#254455"), item["color"].lightened(0.4)))

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
	_refresh_inventory_grid()

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

func _use_item(item_id: String) -> void:
	var item: Dictionary = _get_shop_item(item_id)
	if item.is_empty() or inventory.get(item_id, 0) <= 0:
		return
	if item["effect"] != "heal":
		inventory_feedback.text = "%s 暂无使用效果。" % item["name"]
		return
	if battle_panel != null and battle_panel.visible:
		inventory_feedback.text = "医疗用品只能在牌战外使用。"
		return
	if battle_player_hp >= PLAYER_MAX_HP:
		inventory_feedback.text = "生命值已满，不需要使用医疗用品。"
		return
	var old_hp := battle_player_hp
	var healing_amount: int = int(item["value"]) + _get_talent_bonus("heal_bonus")
	battle_player_hp = mini(PLAYER_MAX_HP, battle_player_hp + healing_amount)
	inventory[item_id] -= 1
	_refresh_player_status_hud()
	_refresh_economy_hud()
	_refresh_inventory_grid()
	inventory_feedback.text = "%s 生效：生命恢复 %d 点。" % [item["name"], battle_player_hp - old_hp]

func _get_shop_item(item_id: String) -> Dictionary:
	for item in shop_items:
		if item["id"] == item_id:
			return item
	return {}

func _start_battle(npc: Node3D, level_id := "") -> void:
	_close_dialogue()
	_close_shop()
	battle_opponent = npc
	var selected_level_id := level_id if not level_id.is_empty() else String(npc.get_meta("level_id", "CH1-01"))
	_start_level(selected_level_id)

func _start_level(level_id: String) -> void:
	if not level_definitions.has(level_id):
		level_id = "CH1-01"
	current_level_id = level_id
	current_level = level_definitions[level_id]
	battle_opponent_name_label.text = "%s  /  %s" % [current_level["name"], current_level["type"]]
	battle_opponent_max_hp = int(current_level["max_hp"])
	battle_opponent_hp = battle_opponent_max_hp
	player_stamina = PLAYER_MAX_STAMINA
	battle_block = _get_talent_bonus("start_block")
	battle_turn = 1
	battle_intent_index = 0
	battle_weakens_opponent = false
	battle_finished = false
	battle_won = false
	battle_feedback_text = String(current_level["pre_battle"])
	battle_deck = player_deck.duplicate()
	battle_discard.clear()
	battle_next_action_damage_bonus = 0
	battle_hand.clear()
	_draw_battle_cards_to_five()
	battle_panel.visible = true
	_refresh_battle_ui()

func _draw_battle_cards_to_five(animate := true) -> void:
	_draw_battle_cards(5 - battle_hand.size(), animate)

func _draw_battle_cards(amount: int, animate := true) -> int:
	var drawn := 0
	for _card_index in range(max(0, amount)):
		if battle_hand.size() >= 5:
			break
		if battle_deck.is_empty():
			if battle_discard.is_empty():
				break
			battle_deck = battle_discard.duplicate()
			battle_discard.clear()
			battle_deck.shuffle()
			if animate:
				battle_shuffle_pending = true
		if battle_deck.is_empty():
			break
		var card_id: String = battle_deck.pop_front()
		battle_hand.append({"id": card_id})
		drawn += 1
		if animate:
			battle_pending_draw_indices.append(battle_hand.size() - 1)
	return drawn

func _play_battle_card(index: int) -> void:
	if not battle_panel.visible or battle_finished:
		return
	if index < 0 or index >= battle_hand.size():
		return
	var card_id: String = battle_hand[index]["id"]
	var card: Dictionary = battle_card_definitions[card_id]
	var card_origin := battle_cards_container.position + battle_card_buttons[index].position
	var card_type := String(card["type"])
	var card_cost := int(card.get("cost", 0))
	if card_cost > player_stamina:
		battle_feedback_text = "体力不足：打出「%s」需要 %d 点体力，当前只有 %d 点。" % [card["name"], card_cost, player_stamina]
		_refresh_battle_ui()
		return
	player_stamina -= card_cost
	var effect := String(card.get("effect", card_type))
	battle_hand.remove_at(index)
	match card_type:
		"action":
			var action_value: int = _get_weapon_base_damage() + int(card["value"])
			if effect in ["damage", "disrupt"]:
				action_value += _get_talent_bonus("action_damage_bonus")
			action_value += battle_next_action_damage_bonus
			battle_next_action_damage_bonus = 0
			if effect == "damage":
				battle_opponent_hp = max(0, battle_opponent_hp - action_value)
				battle_feedback_text = "你使用「%s」，造成 %d 点伤害。" % [card["name"], action_value]
			elif effect == "disrupt":
				battle_opponent_hp = max(0, battle_opponent_hp - action_value)
				battle_weakens_opponent = true
				battle_feedback_text = "你使用「%s」，造成 %d 点伤害并削弱本回合攻击。" % [card["name"], action_value]
			else:
				battle_feedback_text = "你使用「%s」。" % card["name"]
		"defense":
			battle_block += card["value"]
			battle_feedback_text = "你使用「%s」，获得 %d 点格挡。" % [card["name"], card["value"]]
		"tactic":
			var tactic_bonus: int = int(card["value"]) + _get_talent_bonus("tactic_bonus")
			battle_next_action_damage_bonus += tactic_bonus
			battle_feedback_text = "你使用「%s」，下一张行动牌伤害 +%d。" % [card["name"], tactic_bonus]
		"resource":
			var actual_draw_count := _draw_battle_cards(card["value"])
			battle_feedback_text = "你使用「%s」，抽取 %d 张牌。" % [card["name"], actual_draw_count]
		_:
			battle_feedback_text = "你使用「%s」。" % card["name"]
	battle_discard.append(card_id)
	_animate_played_card(card, card_origin)
	if battle_opponent_hp <= 0:
		battle_finished = true
		battle_won = true
		_grant_battle_victory_xp()
	_refresh_battle_ui()

func _end_battle_turn() -> void:
	if not battle_panel.visible:
		return
	if battle_finished:
		_close_battle()
		return
	var current_intent: Dictionary = _get_current_intent()
	var incoming_damage := int(current_intent.get("damage", 8))
	if battle_weakens_opponent:
		incoming_damage = ceili(float(incoming_damage) / 2.0)
	var armor_break := bool(current_intent.get("armor_break", false))
	var blocked_damage: int = 0 if armor_break else min(battle_block, incoming_damage)
	var actual_damage: int = incoming_damage - blocked_damage
	if not armor_break:
		battle_block = max(0, battle_block - incoming_damage)
	battle_player_hp = max(0, battle_player_hp - actual_damage)
	if actual_damage == 0:
		battle_feedback_text = "%s 发动 %d 点攻击，但被你的格挡完全挡下。" % [current_intent.get("name", "敌方"), incoming_damage]
	elif armor_break:
		battle_feedback_text = "%s 穿透格挡，造成 %d 点伤害。" % [current_intent.get("name", "破防攻击"), actual_damage]
	else:
		battle_feedback_text = "%s 发动 %d 点攻击，你受到 %d 点伤害。" % [current_intent.get("name", "敌方"), incoming_damage, actual_damage]
	if battle_player_hp <= 0:
		battle_finished = true
		battle_won = false
		battle_feedback_text = "你输掉了牌战。%s" % current_level.get("defeat_hint", "调整出牌节奏后再来挑战。")
	else:
		battle_turn += 1
		var recovery := int(current_level.get("recovery", BATTLE_STAMINA_PER_TURN))
		if current_intent.has("suppress_recovery"):
			recovery = int(current_intent["suppress_recovery"])
		player_stamina = min(PLAYER_MAX_STAMINA, player_stamina + recovery)
		battle_block = 0
		battle_weakens_opponent = false
		battle_next_action_damage_bonus = 0
		battle_intent_index = (battle_intent_index + 1) % current_level["intents"].size()
		for played_card in battle_hand:
			battle_discard.append(String(played_card["id"]))
		battle_hand.clear()
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
	battle_next_action_damage_bonus = 0

func _get_current_intent() -> Dictionary:
	if current_level.is_empty() or not current_level.has("intents"):
		return {"name": "普通击打", "damage": 8}
	var intents: Array = current_level["intents"]
	if intents.is_empty():
		return {"name": "普通击打", "damage": 8}
	return intents[clampi(battle_intent_index, 0, intents.size() - 1)]

func _refresh_battle_ui() -> void:
	if battle_panel == null or not battle_panel.visible:
		return
	battle_turn_label.text = "DUEL  %02d" % battle_turn
	battle_player_hp_text.text = "%d / %d" % [battle_player_hp, PLAYER_MAX_HP]
	battle_opponent_hp_text.text = "%d / %d" % [battle_opponent_hp, battle_opponent_max_hp]
	battle_player_hp_bar.value = battle_player_hp
	battle_opponent_hp_bar.max_value = battle_opponent_max_hp
	battle_opponent_hp_bar.value = battle_opponent_hp
	battle_stamina_text.text = "%d / %d" % [player_stamina, PLAYER_MAX_STAMINA]
	battle_stamina_bar.value = player_stamina
	battle_xp_text.text = "%d / %d" % [player_xp, XP_PER_LEVEL]
	battle_xp_bar.value = player_xp
	_refresh_player_status_hud()
	battle_title_label.text = "STRATEGY CLUB  //  %s  ·  %s" % [current_level.get("type", "牌战"), current_level.get("name", "牌战协议")]
	battle_status.text = "体力预算  %d / %d     格挡  %d" % [player_stamina, PLAYER_MAX_STAMINA, battle_block]
	battle_deck_label.text = "你的手牌     %d / 5 张  ·  牌库 %d  ·  弃牌 %d" % [battle_hand.size(), battle_deck.size(), battle_discard.size()]
	if battle_finished:
		battle_intent.text = "牌战结束 · %s" % ("胜利" if battle_won else "失败")
	else:
		var intent: Dictionary = _get_current_intent()
		var intent_extra := ""
		if intent.get("charge", false):
			intent_extra = "   ·   下一击 %d" % int(intent.get("next_damage", 0))
		elif intent.get("armor_break", false):
			intent_extra = "   ·   无视格挡"
		elif intent.has("suppress_recovery"):
			intent_extra = "   ·   下回合恢复 %d" % int(intent["suppress_recovery"])
		battle_intent.text = "⚠ %s：预计造成 %d 点伤害%s" % [intent.get("name", "敌方行动"), int(intent.get("damage", 0)), intent_extra]
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
			var card_cost := int(card.get("cost", 0))
			var widgets: Dictionary = battle_card_widgets[index]
			var category_label: Label = widgets["category"]
			category_label.text = category.to_upper()
			category_label.add_theme_color_override("font_color", accent)
			var limit_label: Label = widgets["limit"]
			limit_label.text = "体力 %d" % card_cost
			limit_label.add_theme_color_override("font_color", accent if card_cost <= player_stamina else Color("#64748b"))
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
			description_label.text = _card_display_description(card)
			var footer_label: Label = widgets["footer"]
			footer_label.text = "TYPE %s     /     FIELD TEST" % card_type.to_upper()
			button.add_theme_stylebox_override("normal", _battle_card_style(Color("#202c42"), Color(accent, 0.75)))
			button.add_theme_stylebox_override("hover", _battle_card_style(Color("#2a3a56"), accent))
			button.add_theme_stylebox_override("pressed", _battle_card_style(Color("#151f32"), accent))
			button.disabled = battle_finished or card_cost > player_stamina
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

func _card_category(card_type: String) -> String:
	match card_type:
		"action":
			return "行动"
		"defense":
			return "防御"
		"resource":
			return "资源"
		"tactic":
			return "战术"
		_:
			return card_type

func _card_accent(card_type: String) -> Color:
	match card_type:
		"action":
			return Color("#f87171")
		"defense":
			return Color("#5eead4")
		"resource":
			return Color("#60a5fa")
		"tactic":
			return Color("#c4b5fd")
		_:
			return Color("#fbbf24")

func _card_symbol(card_type: String) -> String:
	match card_type:
		"action":
			return "▲"
		"defense":
			return "◇"
		"resource":
			return "＋"
		"tactic":
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
