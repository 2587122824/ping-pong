extends CanvasLayer

signal close_requested

const UnitScript = preload("res://formation_unit.gd")
const CardViewScript = preload("res://formation_card_view.gd")
const SlotViewScript = preload("res://formation_slot_view.gd")

const STAMINA_MAX := 100
const START_STAMINA := 100
const STAMINA_REGEN_INTERVAL := 1.0
const STAMINA_REGEN_AMOUNT := 2
const ENEMY_REGEN_INTERVAL := 1.0
const ENEMY_REGEN_AMOUNT := 2
const ENEMY_REINFORCE_INTERVAL := 5.0
const HAND_SIZE := 5
const BATTLE_TIME_LIMIT := 90.0
const SUDDEN_DEATH_INTERVAL := 2.0
const SUDDEN_DEATH_DAMAGE := 2
const EMPTY_FIELD_LIMIT := 3.0
const SIM_STEP := 0.05
const MAX_SIM_STEPS := 400
const AURA_STACK_LIMIT := 2
const RESOURCE_UNIT_LIMIT := 2

const LEVEL_ORDER = ["CH0-01", "CH1-01", "CH1-E01", "CH0-B01", "CH1-S01"]
const DECK_ORDER = ["vanguard", "aero", "bastion"]
const LEVEL_SHORT_NAMES = {
	"CH0-01": "教学",
	"CH1-01": "普通",
	"CH1-E01": "精英",
	"CH0-B01": "BOSS",
	"CH1-S01": "支线"
}

var card_definitions := {
	"van_001": {"name": "疾步刀手", "role": "attack", "cost": 5, "hp": 20, "damage": 4, "interval": 1.0, "description": "基础近战速攻，低费铺场。"},
	"van_002": {"name": "双刃突袭者", "role": "attack", "cost": 5, "hp": 20, "damage": 4, "interval": 1.0, "description": "与疾步刀手同价同伤，保证起手密度。"},
	"van_003": {"name": "狂风快斩手", "role": "attack", "cost": 10, "hp": 40, "damage": 5, "interval": 0.9, "description": "高频近战输出。"},
	"van_004": {"name": "绊索斥候", "role": "disrupt", "cost": 10, "hp": 40, "damage": 4, "interval": 1.0, "description": "命中后目标攻击间隔 +50%，持续 3 秒。"},
	"van_005": {"name": "木盾民兵", "role": "defense", "cost": 5, "hp": 30, "damage": 1, "interval": 1.5, "taunt": true, "description": "低费嘲讽前排。"},
	"van_006": {"name": "冲锋号手", "role": "tactic", "cost": 5, "hp": 15, "damage": 0, "interval": 1.0, "aura": 2, "description": "同路相邻友军伤害 +2，不攻击。"},
	"aero_001": {"name": "长弓游侠", "role": "attack", "cost": 15, "hp": 60, "damage": 8, "interval": 1.5, "description": "中费主力输出，站桩持续射击。"},
	"aero_002": {"name": "穿风猎手", "role": "attack", "cost": 10, "hp": 40, "damage": 6, "interval": 1.5, "description": "轻量射手，低费补输出。"},
	"aero_003": {"name": "冰霜术士", "role": "disrupt", "cost": 15, "hp": 60, "damage": 5, "interval": 1.5, "description": "命中后目标攻击间隔 +50%，持续 3 秒。"},
	"aero_004": {"name": "荆棘盾卫", "role": "defense", "cost": 10, "hp": 60, "damage": 1, "interval": 2.0, "taunt": true, "description": "标准中坚嘲讽前排。"},
	"aero_005": {"name": "灵能信标", "role": "resource", "cost": 5, "hp": 15, "damage": 0, "interval": 1.0, "resource": 5, "description": "每 4 秒 +5 体力，不攻击。"},
	"aero_006": {"name": "风语指挥官", "role": "tactic", "cost": 5, "hp": 15, "damage": 0, "interval": 1.0, "aura": 3, "description": "同路相邻友军伤害 +3，不攻击。"},
	"bas_001": {"name": "攻城巨弩", "role": "attack", "cost": 20, "hp": 80, "damage": 10, "interval": 2.0, "description": "重型火力，稳定输出。"},
	"bas_002": {"name": "重型加农炮", "role": "attack", "cost": 15, "hp": 60, "damage": 8, "interval": 2.0, "description": "标准炮击单位。"},
	"bas_003": {"name": "电磁震荡炮", "role": "disrupt", "cost": 20, "hp": 80, "damage": 9, "interval": 2.0, "description": "高伤害迟缓炮击。"},
	"bas_004": {"name": "黑曜石壁垒", "role": "defense", "cost": 15, "hp": 90, "damage": 1, "interval": 2.5, "taunt": true, "description": "超高生命重型嘲讽前排。"},
	"bas_005": {"name": "地热熔炉", "role": "resource", "cost": 5, "hp": 15, "damage": 0, "interval": 1.0, "resource": 5, "description": "每 4 秒 +5 体力，不攻击。"},
	"bas_006": {"name": "高能装填台", "role": "tactic", "cost": 10, "hp": 30, "damage": 0, "interval": 1.0, "aura": 6, "description": "同路相邻友军伤害 +6，不攻击。"},
	"van_061": {"name": "烈焰自爆兵", "role": "attack", "cost": 5, "hp": 15, "damage": 2, "interval": 1.2, "deathrattle": 12, "description": "亡语：对同路敌方第 1 条存活排造成 12 伤害。"},
	"bas_061": {"name": "穿甲狙击手", "role": "attack", "cost": 18, "hp": 60, "damage": 11, "interval": 2.2, "pierce": true, "description": "穿透：无视嘲讽，优先攻击最后排。"},
	"bas_059": {"name": "审判日加农炮", "role": "attack", "cost": 26, "hp": 92, "damage": 12, "interval": 2.4, "charge": 6.0, "description": "蓄力：每 6 秒，下一次攻击 3 倍伤害。"},
	"van_007": {"name": "轻装斥候", "role": "attack", "cost": 3, "hp": 14, "damage": 3, "interval": 0.9, "description": "极低费快速填补空位。"},
	"van_009": {"name": "迅捷剑士", "role": "attack", "cost": 7, "hp": 30, "damage": 4, "interval": 0.85, "description": "攻击速度极快。"},
	"van_033": {"name": "稻草假人", "role": "defense", "cost": 3, "hp": 22, "damage": 0, "interval": 2.0, "taunt": true, "description": "嘲讽：极低费应急挡刀墙。"},
	"van_034": {"name": "轻步圆盾手", "role": "defense", "cost": 6, "hp": 38, "damage": 2, "interval": 1.4, "taunt": true, "description": "嘲讽：标准轻装护卫。"},
	"van_052": {"name": "轻快补给兵", "role": "resource", "cost": 5, "hp": 15, "damage": 0, "interval": 1.0, "resource": 5, "description": "每 4 秒恢复 5 点体力。"},
	"van_056": {"name": "疾跑信使", "role": "resource", "cost": 4, "hp": 16, "damage": 0, "interval": 1.0, "resource": 3, "resource_interval": 3.0, "description": "每 3 秒恢复 3 点体力。"},
	"aero_007": {"name": "羽箭新兵", "role": "attack", "cost": 7, "hp": 30, "damage": 4, "interval": 1.4, "description": "低费补位射手。"},
	"aero_014": {"name": "苍穹神箭手", "role": "attack", "cost": 18, "hp": 72, "damage": 10, "interval": 1.4, "description": "高费游击核心输出。"},
	"aero_029": {"name": "再生苔藓卫", "role": "defense", "cost": 11, "hp": 60, "damage": 1, "interval": 2.0, "taunt": true, "regen": 2, "description": "嘲讽：每秒自动恢复 2 点生命。"},
	"aero_034": {"name": "涌泉图腾", "role": "resource", "cost": 8, "hp": 25, "damage": 0, "interval": 1.0, "resource": 6, "description": "每 4 秒恢复 6 点体力。"},
	"aero_039": {"name": "秘法共鸣石", "role": "resource", "cost": 6, "hp": 18, "damage": 0, "interval": 1.0, "resource": 5, "resource_interval": 5.0, "deploy_stamina": 4, "description": "入场立即恢复 4 点体力，之后每 5 秒恢复 5 点体力。"},
	"aero_048": {"name": "灵羽副官", "role": "tactic", "cost": 12, "hp": 36, "damage": 0, "interval": 1.0, "aura": 4, "description": "光环：同路相邻友军伤害 +4，不攻击。"},
	"bas_007": {"name": "轻型迫击炮", "role": "attack", "cost": 12, "hp": 48, "damage": 6, "interval": 1.9, "description": "低门槛远程火力。"},
	"bas_010": {"name": "稳固炮台", "role": "attack", "cost": 16, "hp": 70, "damage": 9, "interval": 2.1, "back_row_bonus": 2, "description": "站在后排时伤害 +2。"},
	"bas_012": {"name": "怒火榴弹炮", "role": "attack", "cost": 22, "hp": 84, "damage": 13, "interval": 2.3, "healthy_bonus": 4, "description": "目标生命高于 60% 时伤害 +4。"},
	"bas_013": {"name": "堡垒巨炮", "role": "attack", "cost": 25, "hp": 100, "damage": 15, "interval": 2.4, "taunt_front_bonus": 4, "description": "同路前排有嘲讽友军时伤害 +4。"},
	"bas_034": {"name": "装甲补给车", "role": "resource", "cost": 9, "hp": 42, "damage": 0, "interval": 1.0, "resource": 5, "description": "高生存产费单位：每 4 秒恢复 5 点体力。"},
	"bas_040": {"name": "裂变反应堆", "role": "resource", "cost": 15, "hp": 45, "damage": 0, "interval": 1.0, "resource": 10, "description": "每 4 秒恢复 10 点体力。"}
}

var deck_definitions := {
	"vanguard": {"name": "疾锋突击团 · 近战高频", "short": "疾锋", "cards": [
		"van_001", "van_002", "van_003", "van_004", "van_005", "van_006",
		"van_007", "van_009", "van_033", "van_034", "van_052", "van_056"
	]},
	"aero": {"name": "灵羽游击队 · 中距控场", "short": "灵羽", "cards": [
		"aero_001", "aero_002", "aero_003", "aero_004", "aero_005", "aero_006",
		"aero_007", "aero_014", "aero_029", "aero_034", "aero_039", "aero_048"
	]},
	"bastion": {"name": "重炮壁垒军 · 远程重装", "short": "重炮", "cards": [
		"bas_001", "bas_002", "bas_003", "bas_004", "bas_005", "bas_006",
		"bas_007", "bas_010", "bas_012", "bas_013", "bas_034", "bas_040"
	]}
}

var level_definitions := {
	"CH0-01": {
		"name": "新兵试炼 · 教学", "type": "教学", "enemy_deck": "aero",
		"special": "无",
		"hint": "敌方只有两个单位。用远程单位从后排安全输出，或直接压前排。",
		"formation": [
			{"card": "aero_002", "lane": 1, "row": 0},
			{"card": "aero_004", "lane": 0, "row": 0}
		]
	},
	"CH1-01": {
		"name": "前线遭遇 · 普通", "type": "普通", "enemy_deck": "vanguard",
		"special": "亡语：烈焰自爆兵被击破时对同路第 1 存活排造成 12 伤害",
		"hint": "烈焰自爆兵倒下时会炸同路第 1 条存活排。优先清掉它，或用远程在它身后处理，或把低血单位移开这一路。",
		"formation": [
			{"card": "van_001", "lane": 0, "row": 0},
			{"card": "van_002", "lane": 1, "row": 0},
			{"card": "van_003", "lane": 2, "row": 0},
			{"card": "van_061", "lane": 2, "row": 1}
		]
	},
	"CH1-E01": {
		"name": "破阵狙击 · 精英", "type": "精英", "enemy_deck": "bastion",
		"special": "穿透：穿甲狙击手无视嘲讽，优先打最后排",
		"hint": "穿甲狙击手会无视嘲讽，优先攻击最后排。后排放低价值单位，或先击破它。",
		"formation": [
			{"card": "bas_002", "lane": 1, "row": 0},
			{"card": "bas_061", "lane": 0, "row": 0},
			{"card": "bas_006", "lane": 1, "row": 1},
			{"card": "bas_004", "lane": 1, "row": 2},
			{"card": "bas_005", "lane": 2, "row": 2}
		]
	},
	"CH0-B01": {
		"name": "审判日 · BOSS", "type": "BOSS", "enemy_deck": "bastion",
		"special": "蓄力：审判日加农炮每 6 秒蓄力，下次攻击 3 倍",
		"hint": "审判日加农炮每 6 秒蓄力，下一次攻击 3 倍。先击破它，或让它打在你的防御单位上。",
		"formation": [
			{"card": "bas_059", "lane": 0, "row": 0},
			{"card": "bas_002", "lane": 1, "row": 0},
			{"card": "bas_003", "lane": 2, "row": 0},
			{"card": "bas_004", "lane": 1, "row": 1},
			{"card": "bas_006", "lane": 2, "row": 1},
			{"card": "bas_005", "lane": 0, "row": 2}
		]
	},
	"CH1-S01": {
		"name": "寂静力场 · 支线", "type": "支线", "enemy_deck": "aero",
		"special": "压制：冰霜术士存活时玩家体力恢复减半",
		"hint": "冰霜术士存活时，你的体力恢复减半。优先集火它，或者改用低费牌。",
		"formation": [
			{"card": "aero_001", "lane": 0, "row": 0},
			{"card": "aero_002", "lane": 1, "row": 0},
			{"card": "aero_003", "lane": 2, "row": 0},
			{"card": "aero_004", "lane": 1, "row": 1},
			{"card": "aero_005", "lane": 0, "row": 2}
		]
	}
}

var player_character := {
	"name": "你",
	"weapon": "战术指挥徽章",
	"talent": "阵型协同",
	"attack_bonus": 1,
	"hp_ratio": 0.1
}

var enemy_characters := {
	"vanguard": {"name": "近战先遣官", "weapon": "制式长刃", "talent": "突进阵型", "attack_bonus": 1, "hp_ratio": 0.1},
	"aero": {"name": "战术指挥官", "weapon": "灵羽长弓", "talent": "协同布阵", "attack_bonus": 1, "hp_ratio": 0.1},
	"bastion": {"name": "重装炮击手", "weapon": "壁垒重炮", "talent": "阵地压制", "attack_bonus": 1, "hp_ratio": 0.1}
}

var phase := "deploy"
var auto_tick := true
var auto_refresh := true
var speed_multiplier := 1.0
var shuffle_on_reshuffle := true

var level_id := "CH1-01"
var player_deck_id := "vanguard"
var player_stamina := START_STAMINA
var enemy_stamina := 0
var player_stamina_timer := 0.0
var enemy_stamina_timer := 0.0
var enemy_reinforce_timer := 0.0
var enemy_reinforce_index := 0
var battle_time := 0.0
var sudden_death_active := false
var sudden_death_timer := 0.0
var player_empty_timer := 0.0
var enemy_empty_timer := 0.0
var end_reason := ""

var player_deck: Array = []
var player_hand: Array = []
var player_draw_pile: Array = []
var player_discard: Array = []
var board := {}
var deploy_counter := 0
var units_lost := {"player": 0, "enemy": 0}
var selected_card_index := -1
var feedback := ""
var feedback_ok := false
var battle_log: Array = []

var root_ui: Control
var empty_warning_panel: Panel
var empty_warning_title: Label
var empty_warning_count: Label
var empty_warning_hint: Label
var warning_pulse := 0.0
var timer_label: Label
var timer_sub_label: Label
var phase_label: Label
var stamina_bar: ProgressBar
var stamina_text: Label
var stamina_hint: Label
var pile_label: Label
var pile_hint: Label
var log_label: Label
var feedback_label: Label
var level_info_label: Label
var level_buttons := {}
var deck_buttons := {}
var start_button: Button
var speed_button: Button
var auto_deploy_button: Button
var hand_container: HBoxContainer
var card_views: Array = []
var slot_views := {}
var character_views := {}
var move_origin := Vector2i(-1, -1)


func _ready() -> void:
	layer = 30
	_build_ui()
	restart_battle()
	set_process(true)


func _process(delta: float) -> void:
	if not auto_tick:
		return
	if phase != "battle":
		return
	var remaining: float = min(delta * speed_multiplier, 0.5)
	var steps := 0
	while remaining > 0.0001 and steps < 20:
		var step: float = min(remaining, SIM_STEP)
		_simulate(step)
		remaining -= step
		steps += 1
		if phase != "battle":
			break
	if auto_refresh:
		_refresh_dynamic_ui()


func tick(delta: float) -> void:
	var remaining := delta
	var steps := 0
	while remaining > 0.0001 and steps < MAX_SIM_STEPS:
		var step: float = min(remaining, SIM_STEP)
		_simulate(step)
		remaining -= step
		steps += 1
		if phase != "battle":
			break
	if auto_refresh:
		_refresh_dynamic_ui()


func restart_battle() -> void:
	phase = "deploy"
	battle_time = 0.0
	player_stamina = START_STAMINA
	enemy_stamina = 0
	player_stamina_timer = 0.0
	enemy_stamina_timer = 0.0
	enemy_reinforce_timer = 0.0
	enemy_reinforce_index = 0
	sudden_death_active = false
	sudden_death_timer = 0.0
	player_empty_timer = 0.0
	enemy_empty_timer = 0.0
	end_reason = ""
	selected_card_index = -1
	move_origin = Vector2i(-1, -1)
	feedback = ""
	feedback_ok = false
	battle_log.clear()
	player_hand.clear()
	player_draw_pile.clear()
	player_discard.clear()
	deploy_counter = 0
	units_lost = {"player": 0, "enemy": 0}
	player_deck = deck_definitions[player_deck_id]["cards"].duplicate()
	for i in range(min(HAND_SIZE, player_deck.size())):
		player_hand.append(player_deck[i])
	for i in range(player_hand.size(), player_deck.size()):
		player_draw_pile.append(player_deck[i])

	board = {"player": [], "enemy": []}
	for side in ["player", "enemy"]:
		var lanes: Array = []
		for lane in range(3):
			lanes.append([null, null, null])
		board[side] = lanes

	var formation: Array = level_definitions[level_id]["formation"]
	for entry in formation:
		var unit = _create_unit(String(entry["card"]), "enemy", int(entry["lane"]), int(entry["row"]))
		board["enemy"][int(entry["lane"])][int(entry["row"])] = unit

	_add_log("布阵阶段：%s" % String(level_definitions[level_id]["name"]))
	var player_ch: Dictionary = _character_for("player")
	_add_log("人物：%s · %s / %s（全阵攻击 +%d，生命 +%d%%）" % [
		String(player_ch["name"]), String(player_ch["weapon"]), String(player_ch["talent"]),
		int(player_ch["attack_bonus"]), int(round(float(player_ch["hp_ratio"]) * 100.0))
	])
	_add_log("拖拽手牌到阵位；拖到已有单位上会换阵。")
	_set_feedback("拖拽手牌到阵位，或先点手牌再点阵位", true)
	_refresh_character_cards()
	_refresh_hand()
	_refresh_level_info()
	_refresh_dynamic_ui()


func start_battle() -> void:
	if phase != "deploy":
		return
	phase = "battle"
	battle_time = 0.0
	player_stamina_timer = 0.0
	enemy_stamina_timer = 0.0
	enemy_reinforce_timer = 0.0
	sudden_death_active = false
	sudden_death_timer = 0.0
	player_empty_timer = 0.0
	enemy_empty_timer = 0.0
	move_origin = Vector2i(-1, -1)
	for unit in _all_units():
		unit.cooldown = 0.0
		unit.slow_timer = 0.0
		unit.resource_timer = unit.resource_interval
		if unit.charge_interval > 0.0:
			unit.charge_timer = unit.charge_interval
			unit.charge_ready = false
	_add_log("战斗开始：单位自动攻击，体力每 %.0f 秒 +%d" % [STAMINA_REGEN_INTERVAL, STAMINA_REGEN_AMOUNT])
	if _count_side_units("player") == 0:
		_add_log("我方场上为空：%.0f 秒内未部署将判负" % EMPTY_FIELD_LIMIT)
	_set_feedback("战斗开始", true)
	_refresh_dynamic_ui()


func try_deploy(card_id: String, hand_index: int, lane: int, row: int) -> bool:
	if phase != "deploy" and phase != "battle":
		_set_feedback("战斗已结束，不能部署", false)
		return false
	if lane < 0 or lane > 2 or row < 0 or row > 2:
		return false
	if hand_index < 0 or hand_index >= player_hand.size():
		return false
	if String(player_hand[hand_index]) != card_id:
		return false
	if not card_definitions.has(card_id):
		return false
	var cost := int(card_definitions[card_id]["cost"])
	if player_stamina < cost:
		_set_feedback("体力不足：%s 需要 %d，当前 %d" % [
			String(card_definitions[card_id]["name"]), cost, player_stamina
		], false)
		return false

	var old_unit = board["player"][lane][row]
	player_hand.remove_at(hand_index)
	player_stamina -= cost
	player_discard.append(card_id)
	var new_unit = _create_unit(card_id, "player", lane, row)
	board["player"][lane][row] = new_unit
	var action := "部署"
	if old_unit != null:
		action = "换阵"
		old_unit.alive = false
	_add_log("%s %s → %s（-%d 体力）" % [action, new_unit.display_name, _slot_name(lane, row), cost])
	selected_card_index = -1
	var drawn := _draw_card()
	if not drawn.is_empty():
		player_hand.append(drawn)
	_refresh_hand()
	_set_feedback("%s成功：%s" % [action, new_unit.display_name], true)
	_refresh_dynamic_ui()
	return true


func select_card(index: int) -> void:
	if phase != "deploy" and phase != "battle":
		return
	if index < 0 or index >= player_hand.size():
		return
	move_origin = Vector2i(-1, -1)
	if selected_card_index == index:
		selected_card_index = -1
		_set_feedback("取消选择", true)
	else:
		selected_card_index = index
		var card_id := String(player_hand[index])
		var cost := int(card_definitions[card_id]["cost"])
		var suffix := "" if player_stamina >= cost else "（体力不足）"
		_set_feedback("已选中 %s，点击我方阵位部署%s" % [
			String(card_definitions[card_id]["name"]), suffix
		], player_stamina >= cost)
	_refresh_dynamic_ui()


func on_slot_clicked(side: String, lane: int, row: int) -> void:
	if side != "player":
		_set_feedback("敌方阵位不能部署", false)
		return
	if selected_card_index >= 0:
		if selected_card_index >= player_hand.size():
			selected_card_index = -1
			return
		var card_id := String(player_hand[selected_card_index])
		try_deploy(card_id, selected_card_index, lane, row)
		return
	if phase == "deploy":
		if move_origin.x >= 0:
			if move_origin == Vector2i(lane, row):
				move_origin = Vector2i(-1, -1)
				_set_feedback("取消调整", true)
				_refresh_dynamic_ui()
			else:
				try_move_unit(move_origin.x, move_origin.y, lane, row)
			return
		if board["player"][lane][row] != null:
			move_origin = Vector2i(lane, row)
			_set_feedback("已选中 %s：点击目标阵位移动或交换" % String(board["player"][lane][row].display_name), true)
			_refresh_dynamic_ui()
			return
	_set_feedback("先点一张手牌，再点阵位；或直接拖拽手牌", false)


func try_move_unit(from_lane: int, from_row: int, to_lane: int, to_row: int) -> bool:
	if phase != "deploy":
		_set_feedback("开战后不能调整阵型", false)
		return false
	if from_lane < 0 or from_row < 0 or to_lane < 0 or to_row < 0:
		return false
	if from_lane > 2 or from_row > 2 or to_lane > 2 or to_row > 2:
		return false
	if from_lane == to_lane and from_row == to_row:
		return false
	var src = board["player"][from_lane][from_row]
	if src == null or not src.alive:
		return false
	var dst = board["player"][to_lane][to_row]
	board["player"][to_lane][to_row] = src
	src.lane = to_lane
	src.row = to_row
	if dst != null and dst.alive:
		board["player"][from_lane][from_row] = dst
		dst.lane = from_lane
		dst.row = from_row
		_add_log("调整：%s ↔ %s" % [src.display_name, dst.display_name])
		_set_feedback("已交换 %s 与 %s" % [src.display_name, dst.display_name], true)
	else:
		board["player"][from_lane][from_row] = null
		_add_log("调整：%s → %s" % [src.display_name, _slot_name(to_lane, to_row)])
		_set_feedback("已移动 %s 到 %s" % [src.display_name, _slot_name(to_lane, to_row)], true)
	move_origin = Vector2i(-1, -1)
	_refresh_dynamic_ui()
	return true


func can_afford(card_id: String) -> bool:
	if not card_definitions.has(card_id):
		return false
	return player_stamina >= int(card_definitions[card_id]["cost"])


func _simulate(delta: float) -> void:
	if phase != "battle":
		return
	battle_time += delta

	player_stamina_timer += delta
	if player_stamina_timer >= STAMINA_REGEN_INTERVAL:
		player_stamina_timer -= STAMINA_REGEN_INTERVAL
		var player_amount := STAMINA_REGEN_AMOUNT
		if sudden_death_active:
			player_amount = int(round(player_amount * 1.5))
		if _side_has_suppress():
			player_amount = int(ceil(player_amount * 0.5))
		var player_gain: int = min(player_amount, STAMINA_MAX - player_stamina)
		if player_gain > 0:
			player_stamina += player_gain

	enemy_stamina_timer += delta
	if enemy_stamina_timer >= ENEMY_REGEN_INTERVAL:
		enemy_stamina_timer -= ENEMY_REGEN_INTERVAL
		var enemy_amount := ENEMY_REGEN_AMOUNT
		if sudden_death_active:
			enemy_amount = int(round(enemy_amount * 1.5))
		var enemy_gain: int = min(enemy_amount, STAMINA_MAX - enemy_stamina)
		if enemy_gain > 0:
			enemy_stamina += enemy_gain

	enemy_reinforce_timer += delta
	if enemy_reinforce_timer >= ENEMY_REINFORCE_INTERVAL:
		enemy_reinforce_timer -= ENEMY_REINFORCE_INTERVAL
		_try_enemy_reinforce()

	var units := _all_units()
	for unit in units:
		if phase != "battle":
			return
		if unit == null or not unit.alive:
			continue
		if unit.role == "resource":
			unit.resource_timer -= delta
			unit.resource_capped = not _resource_producing(unit)
			if unit.resource_timer <= 0.0:
				unit.resource_timer += unit.resource_interval
				if not unit.resource_capped:
					_grant_stamina(unit.side, unit.resource_amount, "资源 %s" % unit.display_name)
			continue
		if unit.role == "tactic":
			continue
		if unit.slow_timer > 0.0:
			unit.slow_timer = max(0.0, unit.slow_timer - delta)
		if unit.regen_amount > 0 and unit.hp < unit.max_hp:
			unit.regen_timer -= delta
			if unit.regen_timer <= 0.0:
				unit.regen_timer += 1.0
				unit.hp = min(unit.max_hp, unit.hp + unit.regen_amount)
		if unit.charge_interval > 0.0 and not unit.charge_ready:
			unit.charge_timer -= delta
			if unit.charge_timer <= 0.0:
				unit.charge_timer = unit.charge_interval
				unit.charge_ready = true
				_add_log("%s 蓄力就绪，下次攻击 3 倍" % unit.display_name)
		unit.cooldown -= delta
		if unit.cooldown > 0.0:
			continue

		var target = _find_target(unit)
		if target != null:
			var charged: bool = unit.charge_ready
			var damage := _effective_damage(unit, target)
			if charged:
				damage *= 3
				unit.charge_ready = false
				_add_log("%s 蓄力攻击！" % unit.display_name)
			target.hp -= damage
			var slow_text := ""
			if unit.role == "disrupt":
				target.slow_timer = 3.0
				slow_text = "，减速 3s"
			_add_log("%s → %s 造成 %d%s" % [unit.display_name, target.display_name, damage, slow_text])
			if target.hp <= 0:
				_kill_unit(target)
			unit.cooldown = unit.interval * (1.5 if unit.slow_timer > 0.0 else 1.0)
		else:
			unit.cooldown = 0.2

	_update_empty_field(delta)
	if phase != "battle":
		return

	if battle_time >= BATTLE_TIME_LIMIT:
		if not sudden_death_active:
			sudden_death_active = true
			sudden_death_timer = 0.0
			_add_log("%.0f 秒到：突然死亡启动，全场单位每 2 秒 -%d" % [BATTLE_TIME_LIMIT, SUDDEN_DEATH_DAMAGE])
		else:
			sudden_death_timer += delta
			if sudden_death_timer >= SUDDEN_DEATH_INTERVAL:
				sudden_death_timer -= SUDDEN_DEATH_INTERVAL
				_apply_sudden_death_damage()


func _character_for(side: String) -> Dictionary:
	if side == "player":
		return player_character
	var deck_id := String(level_definitions[level_id]["enemy_deck"])
	var character: Dictionary = enemy_characters.get(deck_id, enemy_characters["vanguard"])
	return character


func _character_attack_bonus(side: String) -> int:
	return int(_character_for(side).get("attack_bonus", 0))


func _create_unit(card_id: String, side: String, lane: int, row: int):
	var def: Dictionary = card_definitions[card_id]
	var character: Dictionary = _character_for(side)
	var unit = UnitScript.new()
	unit.card_id = card_id
	unit.display_name = String(def["name"])
	unit.side = side
	unit.lane = lane
	unit.row = row
	unit.role = String(def["role"])
	unit.max_hp = int(floor(float(def["hp"]) * (1.0 + float(character.get("hp_ratio", 0.0)))))
	unit.hp = unit.max_hp
	unit.damage = int(def.get("damage", 0)) + int(character.get("attack_bonus", 0))
	unit.interval = float(def.get("interval", 1.0))
	unit.taunt = bool(def.get("taunt", false))
	unit.aura_bonus = int(def.get("aura", 0))
	unit.resource_amount = int(def.get("resource", 0))
	unit.resource_interval = float(def.get("resource_interval", 4.0))
	unit.cooldown = 0.0
	unit.resource_timer = unit.resource_interval
	unit.slow_timer = 0.0
	unit.alive = true
	unit.deploy_seq = deploy_counter
	deploy_counter += 1
	unit.resource_capped = false
	unit.deathrattle_damage = int(def.get("deathrattle", 0))
	unit.regen_amount = int(def.get("regen", 0))
	unit.regen_timer = 1.0
	unit.back_row_bonus = int(def.get("back_row_bonus", 0))
	unit.healthy_bonus = int(def.get("healthy_bonus", 0))
	unit.taunt_front_bonus = int(def.get("taunt_front_bonus", 0))
	var deploy_gain := int(def.get("deploy_stamina", 0))
	if deploy_gain > 0:
		_grant_stamina(side, deploy_gain, "%s 入场" % unit.display_name)
	if bool(def.get("pierce", false)):
		unit.ignore_taunt = true
		unit.prefer_back = true
	var charge_time := float(def.get("charge", 0.0))
	if charge_time > 0.0:
		unit.charge_interval = charge_time
		unit.charge_timer = charge_time
		unit.charge_ready = false
	if side == "enemy" and level_id == "CH1-S01" and card_id == "aero_003":
		unit.suppress_player_regen = true
	return unit


func _draw_card() -> String:
	if player_draw_pile.is_empty():
		if player_discard.is_empty():
			return ""
		player_draw_pile = player_discard.duplicate()
		player_discard.clear()
		if shuffle_on_reshuffle:
			player_draw_pile.shuffle()
		_add_log("弃牌堆洗回牌库（%d 张）" % player_draw_pile.size())
	return String(player_draw_pile.pop_front())


func _find_target(unit):
	var enemy_side := "enemy" if unit.side == "player" else "player"
	var rows := _occupied_enemy_rows(enemy_side)
	if rows.is_empty():
		return null
	if not unit.prefer_back:
		if not unit.ignore_taunt:
			var taunt_target = _find_same_lane_taunt(unit, enemy_side, rows)
			if taunt_target != null:
				return taunt_target
		if rows.has(0):
			var opposite = board[enemy_side][unit.lane][0]
			if opposite != null and opposite.alive:
				return opposite
	var ordered_rows: Array = rows.duplicate()
	if unit.prefer_back:
		ordered_rows.reverse()
	for row in ordered_rows:
		for lane in range(3):
			var other = board[enemy_side][lane][row]
			if other != null and other.alive:
				return other
	return null


func _occupied_enemy_rows(enemy_side: String) -> Array:
	var rows: Array = []
	for row in range(3):
		for lane in range(3):
			var other = board[enemy_side][lane][row]
			if other != null and other.alive:
				rows.append(row)
				break
	return rows


func _find_same_lane_taunt(unit, enemy_side: String, rows: Array):
	for row in rows:
		var other = board[enemy_side][unit.lane][row]
		if other != null and other.alive and other.taunt:
			return other
	return null


func _effective_damage(unit, target = null) -> int:
	if not unit.is_combat_unit():
		return 0
	var damage: int = int(unit.damage) + _tactic_bonus_for(unit)
	if unit.back_row_bonus > 0 and int(unit.row) == 2:
		damage += unit.back_row_bonus
	if unit.taunt_front_bonus > 0 and _lane_has_taunt_front(unit):
		damage += unit.taunt_front_bonus
	if target != null and unit.healthy_bonus > 0 and int(target.hp) * 100 > int(target.max_hp) * 60:
		damage += unit.healthy_bonus
	return damage


func _lane_has_taunt_front(unit) -> bool:
	var front = board[unit.side][int(unit.lane)][0]
	return front != null and front.alive and front.taunt


func _tactic_bonus_for(unit) -> int:
	if not unit.is_combat_unit():
		return 0
	var aura_values: Array = []
	for row in range(3):
		var ally = board[unit.side][unit.lane][row]
		if ally == null or not ally.alive:
			continue
		if ally.role == "tactic" and abs(int(ally.row) - int(unit.row)) == 1:
			aura_values.append(int(ally.aura_bonus))
	aura_values.sort()
	aura_values.reverse()
	var bonus := 0
	for i in range(min(AURA_STACK_LIMIT, aura_values.size())):
		bonus += int(aura_values[i])
	return bonus


func _resource_producing(unit) -> bool:
	var earlier := 0
	for other in _all_units():
		if other == unit or not other.alive:
			continue
		if other.side != unit.side or other.role != "resource":
			continue
		if int(other.deploy_seq) < int(unit.deploy_seq):
			earlier += 1
	return earlier < RESOURCE_UNIT_LIMIT


func _all_units() -> Array:
	var units: Array = []
	for side in ["player", "enemy"]:
		for row in range(3):
			for lane in range(3):
				var unit = board[side][lane][row]
				if unit != null:
					units.append(unit)
	return units


func _count_units_in_lane(side: String, lane: int) -> int:
	var count := 0
	for row in range(3):
		if board[side][lane][row] != null:
			count += 1
	return count


func _kill_unit(unit) -> void:
	if not unit.alive:
		return
	unit.alive = false
	unit.hp = 0
	board[unit.side][unit.lane][unit.row] = null
	units_lost[unit.side] = int(units_lost[unit.side]) + 1
	var side_text := "我方" if unit.side == "player" else "敌方"
	_add_log("%s %s 被击破，阵位空出" % [side_text, unit.display_name])
	if unit.deathrattle_damage > 0:
		_resolve_deathrattle(unit)


func _resolve_deathrattle(unit) -> void:
	var enemy_side := "enemy" if unit.side == "player" else "player"
	var target = null
	for row in range(3):
		var candidate = board[enemy_side][unit.lane][row]
		if candidate != null and candidate.alive:
			target = candidate
			break
	if target == null:
		return
	target.hp -= unit.deathrattle_damage
	_add_log("%s 亡语 → %s 造成 %d" % [unit.display_name, target.display_name, unit.deathrattle_damage])
	if target.hp <= 0:
		_kill_unit(target)


func _apply_sudden_death_damage() -> void:
	_add_log("突然死亡：全场单位 -%d" % SUDDEN_DEATH_DAMAGE)
	for unit in _all_units():
		if unit == null or not unit.alive:
			continue
		unit.hp -= SUDDEN_DEATH_DAMAGE
		if unit.hp <= 0:
			_kill_unit(unit)


func _lose_battle() -> void:
	phase = "lost"
	_add_log("场上无单位，战斗失败")
	_set_feedback("战斗失败 · 场上空位超过 %.0f 秒" % EMPTY_FIELD_LIMIT, false)


func _count_side_units(side: String) -> int:
	var count := 0
	for lane in range(3):
		for row in range(3):
			if board[side][lane][row] != null:
				count += 1
	return count


func _update_empty_field(delta: float) -> void:
	if _count_side_units("player") == 0:
		player_empty_timer += delta
	else:
		player_empty_timer = 0.0
	if _count_side_units("enemy") == 0:
		enemy_empty_timer += delta
	else:
		enemy_empty_timer = 0.0
	if player_empty_timer < EMPTY_FIELD_LIMIT and enemy_empty_timer < EMPTY_FIELD_LIMIT:
		return

	var player_out: bool = player_empty_timer >= EMPTY_FIELD_LIMIT
	var enemy_out: bool = enemy_empty_timer >= EMPTY_FIELD_LIMIT
	if player_out and enemy_out:
		_add_log("双方同时空场：后空场的一方获胜")
		player_out = player_empty_timer > enemy_empty_timer
		enemy_out = not player_out

	var seconds_text: String = "%.0f" % EMPTY_FIELD_LIMIT
	if player_out:
		end_reason = "场上无单位超过 %s 秒" % seconds_text
		_add_log("我方场上 %s 秒无单位，战斗失败" % seconds_text)
		_lose_battle()
	else:
		phase = "won"
		end_reason = "敌方场上无单位超过 %s 秒" % seconds_text
		_add_log("敌方场上 %s 秒无单位，战斗胜利" % seconds_text)
		_set_feedback("敌方空场 %s 秒，获胜" % seconds_text, true)


func _grant_stamina(side: String, amount: int, source: String) -> void:
	if side == "player":
		var player_gain: int = min(amount, STAMINA_MAX - player_stamina)
		if player_gain <= 0:
			return
		player_stamina += player_gain
		_add_log("%s：体力 +%d" % [source, player_gain])
	else:
		var enemy_gain: int = min(amount, STAMINA_MAX - enemy_stamina)
		if enemy_gain <= 0:
			return
		enemy_stamina += enemy_gain
		_add_log("敌方 %s：体力 +%d" % [source, enemy_gain])


func _side_has_suppress() -> bool:
	for unit in _all_units():
		if unit.side == "enemy" and unit.alive and unit.suppress_player_regen:
			return true
	return false


func _player_has_resource_unit() -> bool:
	for unit in _all_units():
		if unit.side == "player" and unit.alive and unit.role == "resource":
			return true
	return false


func _try_enemy_reinforce() -> void:
	if phase != "battle":
		return
	var deck: Array = deck_definitions[String(level_definitions[level_id]["enemy_deck"])]["cards"]
	if deck.is_empty():
		return
	for offset in range(deck.size()):
		var index := (enemy_reinforce_index + offset) % deck.size()
		var card_id := String(deck[index])
		var cost := int(card_definitions[card_id]["cost"])
		if enemy_stamina < cost:
			continue
		var slot = _enemy_choose_slot(card_id)
		if slot == null:
			continue
		enemy_stamina -= cost
		var unit = _create_unit(card_id, "enemy", int(slot["lane"]), int(slot["row"]))
		board["enemy"][int(slot["lane"])][int(slot["row"])] = unit
		enemy_reinforce_index = (index + 1) % deck.size()
		_add_log("敌方补位 %s → %s（-%d 体力）" % [
			unit.display_name, _slot_name(int(slot["lane"]), int(slot["row"])), cost
		])
		return


func _enemy_choose_slot(card_id: String):
	var role := String(card_definitions[card_id]["role"])
	var best_lane := -1
	var best_score := -9999
	var best_rows: Array = []
	for lane in range(3):
		var empty_rows: Array = []
		for row in range(3):
			if board["enemy"][lane][row] == null:
				empty_rows.append(row)
		if empty_rows.is_empty():
			continue
		var player_count := _count_units_in_lane("player", lane)
		var score := player_count * 10
		if (role == "attack" or role == "disrupt") and player_count == 0:
			score += 30
		if role == "defense" and player_count > 0:
			score += 5
		if score > best_score:
			best_score = score
			best_lane = lane
			best_rows = empty_rows
	if best_lane < 0:
		return null
	var preference: Array = [0, 1, 2]
	if role == "resource":
		preference = [2, 1, 0]
	elif role == "tactic":
		preference = [1, 2, 0]
	for row in preference:
		if best_rows.has(row):
			return {"lane": best_lane, "row": row}
	return {"lane": best_lane, "row": int(best_rows[0])}


func _slot_name(lane: int, row: int) -> String:
	var lane_names := ["上路", "中路", "下路"]
	var row_names := ["前排", "中排", "后排"]
	return "%s%s" % [lane_names[lane], row_names[row]]


func _add_log(text: String) -> void:
	var prefix := "[布阵] " if phase == "deploy" else "[%5.1f] " % battle_time
	battle_log.append(prefix + text)
	if battle_log.size() > 30:
		battle_log.pop_front()


func _set_feedback(text: String, ok: bool) -> void:
	feedback = text
	feedback_ok = ok
	if feedback_label != null:
		feedback_label.text = text
		feedback_label.add_theme_color_override("font_color", Color("#86efac") if ok else Color("#fca5a5"))


func _refresh_hand() -> void:
	for child in hand_container.get_children():
		hand_container.remove_child(child)
		child.queue_free()
	card_views.clear()
	for index in range(player_hand.size()):
		var card_id := String(player_hand[index])
		var view = CardViewScript.new()
		view.setup(self, index, card_id)
		hand_container.add_child(view)
		card_views.append(view)
	_refresh_card_states()


func _refresh_card_states() -> void:
	for index in range(card_views.size()):
		if index >= player_hand.size():
			continue
		var view = card_views[index]
		var card_id := String(player_hand[index])
		view.set_state(index == selected_card_index, can_afford(card_id))


func _refresh_level_info() -> void:
	var level: Dictionary = level_definitions[level_id]
	var deck: Dictionary = deck_definitions[player_deck_id]
	var cards: Array = deck["cards"]
	var costs: Array = []
	var total_cost := 0
	for card_id in cards:
		var cost := int(card_definitions[card_id]["cost"])
		costs.append(cost)
		total_cost += cost
	costs.sort()
	var fill_total := 0
	for i in range(costs.size()):
		if i >= 9:
			break
		fill_total += int(costs[i])
	var fill_line := "9 格最低铺满：共 %d，剩 %d。" % [fill_total, STAMINA_MAX - fill_total]
	if fill_total > STAMINA_MAX:
		fill_line = "9 格最低铺满需 %d，体力不足。" % fill_total
	level_info_label.text = "关卡：%s\n敌方牌组：%s\n特殊：%s\n\n%s\n\n%s 12 张牌库，总费用 %d。\n%s" % [
		String(level["name"]),
		String(deck_definitions[String(level["enemy_deck"])]["short"]),
		String(level["special"]),
		String(level["hint"]),
		String(deck["short"]),
		total_cost,
		fill_line
	]


func _refresh_dynamic_ui() -> void:
	if stamina_bar == null:
		return
	stamina_bar.max_value = STAMINA_MAX
	stamina_bar.value = max(0, player_stamina)
	stamina_text.text = "%d / %d" % [max(0, player_stamina), STAMINA_MAX]

	if phase == "deploy":
		stamina_hint.text = "布阵阶段不恢复\n开战后每 %.0f 秒 +%d" % [STAMINA_REGEN_INTERVAL, STAMINA_REGEN_AMOUNT]
	elif phase == "battle":
		var until: float = max(0.0, STAMINA_REGEN_INTERVAL - player_stamina_timer)
		var hint: String = "下次恢复 %.1fs" % until
		if _player_has_resource_unit():
			hint += "\n资源牌按卡面间隔恢复体力（最多 2 个生效）"
		stamina_hint.text = hint
	else:
		stamina_hint.text = "战斗结束"

	match phase:
		"deploy":
			timer_label.text = "布阵阶段"
			timer_sub_label.text = "不限时"
			phase_label.text = "布阵阶段 · 拖牌入场，可拖动已上阵单位调整，按空格开战"
			phase_label.add_theme_color_override("font_color", Color("#7dd3fc"))
			start_button.text = "开始战斗"
		"battle":
			timer_label.text = "%.1f s" % battle_time
			timer_sub_label.text = "突然死亡中" if sudden_death_active else "90s 突然死亡"
			if player_empty_timer > 0.0:
				var life_left: float = max(0.0, EMPTY_FIELD_LIMIT - player_empty_timer)
				phase_label.text = "我方场上无单位：%.1f 秒后判负" % life_left
				phase_label.add_theme_color_override("font_color", Color("#f87171"))
			elif enemy_empty_timer > 0.0:
				var win_left: float = max(0.0, EMPTY_FIELD_LIMIT - enemy_empty_timer)
				phase_label.text = "敌方场上无单位：%.1f 秒后获胜" % win_left
				phase_label.add_theme_color_override("font_color", Color("#fde047"))
			else:
				phase_label.text = "实时战斗 · 自动攻击"
				phase_label.add_theme_color_override("font_color", Color("#86efac"))
			start_button.text = "重新开始"
		"won":
			timer_label.text = "胜利"
			timer_sub_label.text = "用时 %.1f s" % battle_time
			phase_label.text = "胜利 · %s" % end_reason
			phase_label.add_theme_color_override("font_color", Color("#fde047"))
			start_button.text = "再次挑战"
		"lost":
			timer_label.text = "失败"
			timer_sub_label.text = "用时 %.1f s" % battle_time
			phase_label.text = "失败 · %s" % end_reason
			phase_label.add_theme_color_override("font_color", Color("#fca5a5"))
			start_button.text = "再次挑战"

	_update_empty_warning()

	pile_label.text = "牌库 %d · 弃牌 %d\n手牌 %d / %d" % [
		player_draw_pile.size(), player_discard.size(), player_hand.size(), HAND_SIZE
	]
	log_label.text = _recent_log_text()
	feedback_label.text = feedback
	feedback_label.add_theme_color_override("font_color", Color("#86efac") if feedback_ok else Color("#fca5a5"))
	_refresh_card_states()
	speed_button.text = "速度 x%d" % int(speed_multiplier)
	if auto_deploy_button != null:
		auto_deploy_button.disabled = phase != "deploy"

	if board.is_empty():
		return
	var placing := selected_card_index >= 0 and (phase == "deploy" or phase == "battle")
	if placing and selected_card_index < player_hand.size():
		placing = can_afford(String(player_hand[selected_card_index]))
	else:
		placing = false
	for side in ["player", "enemy"]:
		for lane in range(3):
			for row in range(3):
				var view = slot_views[side][lane][row]
				view.set_highlight(side == "player" and move_origin == Vector2i(lane, row))
				view.set_placeable(side == "player" and placing)
				view.refresh(board[side][lane][row])
	_refresh_button_highlights()


func _update_empty_warning() -> void:
	if empty_warning_panel == null:
		return
	var player_empty: bool = player_empty_timer > 0.0
	var enemy_empty: bool = enemy_empty_timer > 0.0
	var show_warning: bool = phase == "battle" and (player_empty or enemy_empty)
	empty_warning_panel.visible = show_warning
	if not show_warning:
		empty_warning_panel.modulate = Color.WHITE
		return

	var player_losing: bool = player_empty
	var deadline: float = player_empty_timer
	if player_empty and enemy_empty:
		player_losing = player_empty_timer > enemy_empty_timer
		deadline = max(player_empty_timer, enemy_empty_timer)
	elif enemy_empty:
		deadline = enemy_empty_timer

	if player_empty and enemy_empty:
		empty_warning_title.text = "双方场上均无单位"
		empty_warning_hint.text = "同时空场我方获胜" if player_empty_timer <= enemy_empty_timer else "我方先空场将判负"
	elif player_losing:
		empty_warning_title.text = "我方场上无单位"
		empty_warning_hint.text = "倒计时结束判负"
	else:
		empty_warning_title.text = "敌方场上无单位"
		empty_warning_hint.text = "倒计时结束获胜"
	empty_warning_count.text = "%.1f" % max(0.0, EMPTY_FIELD_LIMIT - deadline)
	var accent := Color("#f87171") if player_losing else Color("#facc15")
	empty_warning_count.add_theme_color_override("font_color", accent)
	empty_warning_title.add_theme_color_override("font_color", accent.lightened(0.45))
	var panel_style: StyleBoxFlat = empty_warning_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if panel_style != null:
		panel_style.border_color = accent
	warning_pulse += 0.18
	var pulse: float = absf(sin(warning_pulse))
	empty_warning_panel.modulate = Color(1.0, 1.0, 1.0, 0.7 + 0.3 * pulse)


func _recent_log_text() -> String:
	var start := battle_log.size() - 14
	if start < 0:
		start = 0
	var text := ""
	for i in range(start, battle_log.size()):
		if not text.is_empty():
			text += "\n"
		text += String(battle_log[i])
	return text


func _refresh_button_highlights() -> void:
	for key in level_buttons:
		var button: Button = level_buttons[key]
		button.modulate = Color("#7fe4dd") if key == level_id else Color.WHITE
	for key in deck_buttons:
		var button: Button = deck_buttons[key]
		button.modulate = Color("#7fe4dd") if key == player_deck_id else Color.WHITE


func _on_level_pressed(id: String) -> void:
	level_id = id
	restart_battle()
	_set_feedback("已切换到 %s" % String(level_definitions[level_id]["name"]), true)
	_refresh_dynamic_ui()


func _on_deck_pressed(id: String) -> void:
	player_deck_id = id
	restart_battle()
	_set_feedback("已切换到 %s" % String(deck_definitions[player_deck_id]["name"]), true)
	_refresh_dynamic_ui()


func _on_start_pressed() -> void:
	if phase == "deploy":
		start_battle()
	else:
		restart_battle()


func _on_auto_deploy_pressed() -> void:
	auto_deploy_formation()


func auto_deploy_formation() -> int:
	if phase != "deploy":
		_set_feedback("只有布阵阶段可以一键布阵", false)
		return 0
	selected_card_index = -1
	move_origin = Vector2i(-1, -1)
	var deployed := 0
	while true:
		var slot := _first_empty_player_slot()
		if slot.x < 0:
			break
		var hand_index := _auto_deploy_card_index(slot.y)
		if hand_index < 0:
			break
		var card_id := String(player_hand[hand_index])
		if not try_deploy(card_id, hand_index, slot.x, slot.y):
			break
		deployed += 1
	if deployed == 0:
		_set_feedback("没有空位或体力不足，无法一键布阵", false)
	else:
		_set_feedback("一键布阵：部署 %d 个单位" % deployed, true)
	_refresh_dynamic_ui()
	return deployed


func auto_reinforce_battle() -> bool:
	if phase != "battle":
		return false
	var slot := _first_empty_player_slot()
	if slot.x < 0:
		return false
	var hand_index := _auto_deploy_card_index(slot.y)
	if hand_index < 0:
		return false
	var card_id := String(player_hand[hand_index])
	return try_deploy(card_id, hand_index, slot.x, slot.y)


func _first_empty_player_slot() -> Vector2i:
	var row_order: Array[int] = [0, 2, 1]
	for row in row_order:
		for lane in range(3):
			if board["player"][lane][row] == null:
				return Vector2i(lane, row)
	return Vector2i(-1, -1)


func _auto_deploy_card_index(row: int) -> int:
	var best_index := -1
	var best_score := -1
	var best_cost := 999
	for index in range(player_hand.size()):
		var card_id := String(player_hand[index])
		if not can_afford(card_id):
			continue
		var score := _auto_deploy_score(card_id, row)
		var cost := int(card_definitions[card_id]["cost"])
		if score > best_score or (score == best_score and cost < best_cost):
			best_index = index
			best_score = score
			best_cost = cost
	return best_index


func _auto_deploy_score(card_id: String, row: int) -> int:
	var role := String(card_definitions[card_id]["role"])
	if row == 0:
		match role:
			"defense": return 40
			"attack": return 30
			"disrupt": return 25
			"tactic": return 10
			"resource": return 5
	elif row == 1:
		match role:
			"attack": return 30
			"disrupt": return 30
			"tactic": return 25
			"defense": return 20
			"resource": return 20
	else:
		match role:
			"resource": return 40
			"tactic": return 35
			"attack": return 30
			"disrupt": return 20
			"defense": return 5
	return 0


func _on_speed_pressed() -> void:
	if speed_multiplier < 2.0:
		speed_multiplier = 2.0
	elif speed_multiplier < 4.0:
		speed_multiplier = 4.0
	else:
		speed_multiplier = 1.0
	_refresh_dynamic_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_request_close()
		elif event.keycode == KEY_SPACE and phase == "deploy":
			get_viewport().set_input_as_handled()
			start_battle()


func _request_close() -> void:
	if close_requested.get_connections().is_empty():
		var error := get_tree().change_scene_to_file("res://Main.tscn")
		if error != OK:
			get_tree().quit()
	else:
		close_requested.emit()


func _build_ui() -> void:
	root_ui = Control.new()
	root_ui.position = Vector2.ZERO
	root_ui.size = Vector2(1280, 720)
	root_ui.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root_ui)

	var background := ColorRect.new()
	background.position = Vector2.ZERO
	background.size = Vector2(1280, 720)
	background.color = Color("#060d17")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(background)

	var title := _add_label(root_ui, Vector2(24, 12), Vector2(620, 30), "实时布阵自动战斗 · 原型", 22, Color("#e2e8f0"))
	title.add_theme_color_override("font_color", Color("#7dd3fc"))
	_add_button(root_ui, Vector2(1186, 12), Vector2(70, 32), "关闭", _request_close)

	_add_label(root_ui, Vector2(24, 54), Vector2(54, 20), "关卡", 13, Color("#94a3b8"))
	level_buttons.clear()
	for i in range(LEVEL_ORDER.size()):
		var level_key: String = LEVEL_ORDER[i]
		level_buttons[level_key] = _add_button(
			root_ui,
			Vector2(80 + i * 90, 48),
			Vector2(84, 32),
			String(LEVEL_SHORT_NAMES[level_key]),
			_on_level_pressed.bind(level_key)
		)

	_add_label(root_ui, Vector2(556, 54), Vector2(54, 20), "牌组", 13, Color("#94a3b8"))
	deck_buttons.clear()
	for i in range(DECK_ORDER.size()):
		var deck_key: String = DECK_ORDER[i]
		deck_buttons[deck_key] = _add_button(
			root_ui,
			Vector2(610 + i * 110, 48),
			Vector2(104, 32),
			String(deck_definitions[deck_key]["short"]),
			_on_deck_pressed.bind(deck_key)
		)

	speed_button = _add_button(root_ui, Vector2(950, 48), Vector2(90, 32), "速度 x1", _on_speed_pressed)
	start_button = _add_button(root_ui, Vector2(1050, 48), Vector2(126, 32), "开始战斗", _on_start_pressed)

	phase_label = _add_label(root_ui, Vector2(24, 88), Vector2(560, 18), "布阵阶段 · 拖牌入场，可拖动已上阵单位调整，按空格开战", 13, Color("#7dd3fc"))

	var timer_panel := _make_panel(root_ui, Vector2(560, 112), Vector2(160, 54), Color(0.02, 0.05, 0.08, 0.92), Color("#334155"))
	timer_label = _add_label(timer_panel, Vector2(0, 7), Vector2(160, 22), "布阵阶段", 16, Color("#e2e8f0"))
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_sub_label = _add_label(timer_panel, Vector2(0, 30), Vector2(160, 16), "不限时", 10, Color("#94a3b8"))
	timer_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var goal_panel := _make_panel(root_ui, Vector2(876, 112), Vector2(380, 54), Color(0.03, 0.05, 0.08, 0.92), Color("#22c55e"))
	_add_label(goal_panel, Vector2(12, 6), Vector2(356, 18), "胜利：敌方场上无单位 3 秒", 12, Color("#86efac"))
	_add_label(goal_panel, Vector2(12, 28), Vector2(356, 18), "失败：我方场上无单位 3 秒", 12, Color("#fca5a5"))

	var log_panel := _make_panel(root_ui, Vector2(24, 176), Vector2(238, 428), Color(0.02, 0.05, 0.08, 0.92), Color("#1e3a4a"))
	_add_label(log_panel, Vector2(14, 10), Vector2(200, 22), "战报", 16, Color("#7dd3fc"))
	log_label = _add_label(log_panel, Vector2(12, 36), Vector2(214, 348), "", 10, Color("#cbd5e1"))
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	feedback_label = _add_label(log_panel, Vector2(12, 394), Vector2(214, 24), "", 11, Color("#86efac"))
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var info_panel := _make_panel(root_ui, Vector2(974, 176), Vector2(282, 428), Color(0.03, 0.02, 0.06, 0.92), Color("#4c1d95"))
	_add_label(info_panel, Vector2(14, 10), Vector2(250, 22), "规则与关卡", 16, Color("#c084fc"))
	var rules_label := _add_label(info_panel, Vector2(12, 36), Vector2(258, 152), "3 路 × 3 排；单位原位不移动。\n同路嘲讽优先，其次正对面第一排；\n跨路时同排从上到下（上→中→下）。\n所有单位均可攻击任意存活排。\n关键词：嘲讽 / 迟缓 / 光环 / 蓄力 / 穿透 / 亡语。\n同路单单位最多 2 层光环；每方最多 2 个资源单位产费。\n90 秒后每 2 秒全场 -2，体力恢复 +50%。\n拖手牌到阵位；拖动已上阵单位可调整位置。", 9, Color("#cbd5e1"))
	rules_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	level_info_label = _add_label(info_panel, Vector2(12, 200), Vector2(258, 186), "", 9, Color("#fde68a"))
	level_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_add_label(info_panel, Vector2(12, 394), Vector2(258, 26), "原型：单场战斗，胜负只看场上是否空场 3 秒。", 9, Color("#94a3b8"))

	var board_panel := _make_panel(root_ui, Vector2(270, 176), Vector2(696, 428), Color(0.015, 0.04, 0.07, 0.88), Color("#1e293b"))
	_add_label(board_panel, Vector2(62, 12), Vector2(200, 20), "我方阵型", 13, Color("#7dd3fc"))
	var enemy_side_title := _add_label(board_panel, Vector2(422, 12), Vector2(200, 20), "敌方阵型", 13, Color("#fca5a5"))
	enemy_side_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var net_title := _add_label(board_panel, Vector2(326, 13), Vector2(30, 18), "网", 10, Color("#94a3b8"))
	net_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var column_titles := ["我后", "我中", "我前", "敌前", "敌中", "敌后"]
	for col in range(6):
		var column_title := _add_label(board_panel, Vector2(62 + col * 94, 46), Vector2(90, 16), column_titles[col], 10, Color("#64748b"))
		column_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var net := ColorRect.new()
	net.position = Vector2(341, 46)
	net.size = Vector2(2, 298)
	net.color = Color("#475569")
	net.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_panel.add_child(net)

	var board_hint := _add_label(board_panel, Vector2(62, 366), Vector2(560, 20), "拖拽手牌入场 · 点牌再点阵位部署 · 拖动已上阵单位调整位置", 10, Color("#64748b"))
	board_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	auto_deploy_button = _add_button(board_panel, Vector2(62, 390), Vector2(150, 30), "一键布阵", _on_auto_deploy_pressed)

	slot_views = {"player": [], "enemy": []}
	for side in ["player", "enemy"]:
		var lanes: Array = []
		for lane in range(3):
			var rows: Array = []
			for row in range(3):
				var view = SlotViewScript.new()
				view.position = _slot_position(side, lane, row)
				view.size = Vector2(90, 84)
				board_panel.add_child(view)
				view.setup(self, side, lane, row)
				rows.append(view)
			lanes.append(rows)
		slot_views[side] = lanes

	_build_character_card(board_panel, "player", 6.0)
	_build_character_card(board_panel, "enemy", 628.0)
	_refresh_character_cards()

	var stamina_panel := _make_panel(root_ui, Vector2(24, 606), Vector2(190, 100), Color(0.02, 0.05, 0.08, 0.92), Color("#fbbf24"))
	_add_label(stamina_panel, Vector2(12, 6), Vector2(80, 18), "体力", 13, Color("#fbbf24"))
	stamina_text = _add_label(stamina_panel, Vector2(88, 6), Vector2(90, 18), "100 / 100", 13, Color("#fef3c7"))
	stamina_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stamina_bar = _add_bar(stamina_panel, Vector2(12, 30), Vector2(166, 14), STAMINA_MAX, Color("#fbbf24"))
	stamina_hint = _add_label(stamina_panel, Vector2(12, 64), Vector2(166, 30), "布阵阶段不恢复\n开战后每 %.0f 秒 +%d" % [STAMINA_REGEN_INTERVAL, STAMINA_REGEN_AMOUNT], 9, Color("#cbd5e1"))
	stamina_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var pile_panel := _make_panel(root_ui, Vector2(1064, 606), Vector2(192, 100), Color(0.02, 0.05, 0.08, 0.92), Color("#475569"))
	pile_label = _add_label(pile_panel, Vector2(12, 8), Vector2(168, 34), "", 11, Color("#cbd5e1"))
	pile_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pile_hint = _add_label(pile_panel, Vector2(12, 52), Vector2(168, 40), "拖拽或点击部署\n已上阵单位可拖动调整", 9, Color("#94a3b8"))
	pile_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	hand_container = HBoxContainer.new()
	hand_container.position = Vector2(230, 606)
	hand_container.size = Vector2(820, 100)
	hand_container.add_theme_constant_override("separation", 10)
	hand_container.alignment = BoxContainer.ALIGNMENT_CENTER
	root_ui.add_child(hand_container)

	empty_warning_panel = _make_panel(root_ui, Vector2(408, 292), Vector2(460, 168), Color(0.16, 0.02, 0.04, 0.62), Color("#ef4444"))
	empty_warning_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	empty_warning_panel.visible = false
	var warning_style: StyleBoxFlat = empty_warning_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if warning_style != null:
		warning_style.set_border_width_all(3)
	empty_warning_title = _add_label(empty_warning_panel, Vector2(0, 14), Vector2(460, 34), "", 24, Color("#fecaca"))
	empty_warning_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_warning_count = _add_label(empty_warning_panel, Vector2(0, 52), Vector2(460, 64), "", 48, Color("#f87171"))
	empty_warning_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_warning_hint = _add_label(empty_warning_panel, Vector2(0, 126), Vector2(460, 24), "", 14, Color("#fca5a5"))
	empty_warning_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _slot_position(side: String, lane: int, row: int) -> Vector2:
	var col := (2 - row) if side == "player" else (3 + row)
	return Vector2(62 + col * 94, 68 + lane * 96)


func _build_character_card(parent: Control, side: String, x: float) -> void:
	var accent := Color("#38bdf8") if side == "player" else Color("#f87171")
	var panel := _make_panel(parent, Vector2(x, 106), Vector2(50, 200), Color(0.02, 0.05, 0.08, 0.94), accent)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var title := _add_label(panel, Vector2(0, 8), Vector2(50, 14), "人物", 8, Color("#94a3b8"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var name_label := _add_label(panel, Vector2(0, 24), Vector2(50, 20), "", 11, accent)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var weapon_title := _add_label(panel, Vector2(0, 58), Vector2(50, 12), "武器", 8, Color("#64748b"))
	weapon_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var weapon_label := _add_label(panel, Vector2(0, 70), Vector2(50, 28), "", 9, Color("#cbd5e1"))
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weapon_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var talent_title := _add_label(panel, Vector2(0, 104), Vector2(50, 12), "天赋", 8, Color("#64748b"))
	talent_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var talent_label := _add_label(panel, Vector2(0, 116), Vector2(50, 28), "", 9, Color("#cbd5e1"))
	talent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	talent_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var bonus_label := _add_label(panel, Vector2(0, 154), Vector2(50, 38), "", 9, accent)
	bonus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bonus_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	character_views[side] = {
		"panel": panel,
		"name": name_label,
		"weapon": weapon_label,
		"talent": talent_label,
		"bonus": bonus_label
	}


func _refresh_character_cards() -> void:
	for side in ["player", "enemy"]:
		if not character_views.has(side):
			continue
		var character: Dictionary = _character_for(side)
		var view: Dictionary = character_views[side]
		var attack_bonus := int(character.get("attack_bonus", 0))
		var hp_percent := int(round(float(character.get("hp_ratio", 0.0)) * 100.0))
		var name_label: Label = view["name"]
		var weapon_label: Label = view["weapon"]
		var talent_label: Label = view["talent"]
		var bonus_label: Label = view["bonus"]
		var panel: Panel = view["panel"]
		name_label.text = String(character["name"])
		weapon_label.text = String(character["weapon"])
		talent_label.text = String(character["talent"])
		bonus_label.text = "+%d 攻击\n+%d%% 生命" % [attack_bonus, hp_percent]
		panel.tooltip_text = "%s\n武器：%s（全阵攻击 +%d）\n天赋：%s（全阵生命 +%d%%）" % [
			String(character["name"]), String(character["weapon"]), attack_bonus,
			String(character["talent"]), hp_percent
		]


func _make_panel_style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style


func _make_panel(parent: Control, pos: Vector2, panel_size: Vector2, bg: Color, border: Color) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = panel_size
	panel.add_theme_stylebox_override("panel", _make_panel_style(bg, border, 8))
	parent.add_child(panel)
	return panel


func _add_label(parent: Control, pos: Vector2, label_size: Vector2, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = label_size
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _add_button(parent: Control, pos: Vector2, button_size: Vector2, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.position = pos
	button.size = button_size
	button.text = text
	button.add_theme_font_size_override("font_size", 13)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _add_bar(parent: Control, pos: Vector2, bar_size: Vector2, max_value: int, fill_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = pos
	bar.size = bar_size
	bar.min_value = 0
	bar.max_value = max_value
	bar.value = max_value
	bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("#1f2937")
	bg.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	return bar
