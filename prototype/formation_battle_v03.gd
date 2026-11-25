extends Node3D

# 实时布阵自动战斗 V0.3（3D 桌面战场原型）
# 依据 docs/FORMATION_BATTLE_V0_3.md：
# - 3 路 × 7 排站桩阵型，near/mid/far 三个战术区域
# - 单位没有生命值，靠出手次数 / 持续时间 / 被克制退场
# - 全场共用一颗主炸弹：招式推动它压向我方/敌方半场，定时或推到底线引爆
# - 双方主体生命：玩家 100，BOSS 独立血量
# - 单一乒乓球招式牌组 13 张，费用 10-35，武器「木棍」给快攻 +1 次出手

const LANES := 3
const ROWS := 7
const STAMINA_MAX := 100
const START_STAMINA := 100
const REGEN_INTERVAL := 1.0
const REGEN_AMOUNT := 5
const ENEMY_REGEN_AMOUNT := 1
const HAND_SIZE := 5
const BOMB_TIMER := 7.0
const BOMB_RANGE := 7.0
const BOMB_DAMAGE := 15
const BOMB_RESPAWN := 3.0
const BASELINE_DAMAGE := 22
const PLAYER_MAX_HP := 100
const BATTLE_LIMIT := 90.0
const ENEMY_DEPLOY_INTERVAL := 2.4
# 主动换阵覆盖：返还被替换单位费用的比例
const SWAP_REFUND := 0.25
# 炸弹冲击波：震掉受击方前排（近台）单位的出手次数
const SHOCKWAVE_DRAIN := 1
# 克制压制：明显克制（倍率 ≥ 阈值）命中时削守方出手次数；控台单位不吃直接压制
const COUNTER_SUPPRESS_MULT := 1.3
const COUNTER_SUPPRESS_DRAIN := 1

const ZONE_ROWS := {"near": [0, 1], "mid": [2, 3, 4], "far": [5, 6]}
const ZONE_NAMES := {"near": "近台", "mid": "中台", "far": "远台"}

# 攻方类型 → 守方类型的推力倍率（1.5 = 明显克制，0.5 = 被反制）
const COUNTER := {
	"fast": {"fast": 1.0, "spin": 1.5, "control": 0.9, "counter": 0.6},
	"spin": {"fast": 1.3, "spin": 1.0, "control": 0.7, "counter": 0.5},
	"control": {"fast": 1.0, "spin": 0.9, "control": 1.0, "counter": 0.9},
	"counter": {"fast": 0.8, "spin": 1.4, "control": 1.0, "counter": 1.0}
}

const CARDS := {
	"tt_sub": {
		"name": "正手快带", "type": "fast", "cost": 10, "zone": ["near"],
		"actions": 3, "interval": 1.0, "push": 0.8,
		"desc": "低费极速出拍，抢中线先手，克制慢速蓄力。"
	},
	"tt_main": {
		"name": "正手快攻", "type": "fast", "cost": 15, "zone": ["near"],
		"actions": 4, "interval": 1.1, "push": 1.0, "forehand_synergy": 0.4,
		"desc": "稳定高频推压；同路有其他正手招式时推力 +0.4。"
	},
	"tt_rip": {
		"name": "反手快攻", "type": "fast", "cost": 15, "zone": ["near", "mid"],
		"actions": 3, "interval": 1.0, "push": 0.9, "entry_push": 1.0,
		"desc": "灵活补位，入场立即免费推击一次。"
	},
	"tt_short": {
		"name": "摆短", "type": "control", "cost": 15, "zone": ["near"],
		"duration": 8.0, "interval": 1.0,
		"debuff": {"type": "spin", "ratio": 0.5, "interval_mult": 1.5},
		"desc": "压制敌方弧圈类推力减半、出手变慢，持续 8 秒。"
	},
	"tt_long": {
		"name": "劈长", "type": "control", "cost": 15, "zone": ["far"],
		"duration": 8.0, "interval": 1.0,
		"debuff": {"type": "fast", "ratio": 0.6, "interval_mult": 1.3},
		"desc": "限制敌方近台快攻推力，并拖慢其出手节奏，持续 8 秒。"
	},
	"tt_serve": {
		"name": "转不转发球", "type": "control", "cost": 15, "zone": ["far"],
		"duration": 8.0, "interval": 1.0, "resource": 3, "resource_interval": 3.0,
		"reverse_first": true,
		"desc": "每 3 秒 +3 体力；敌方本路第一次进攻会被吃转反推。"
	},
	"tt_tear": {
		"name": "反手快撕", "type": "counter", "cost": 20, "zone": ["mid"],
		"actions": 3, "interval": 1.2, "push": 1.0, "reflect": ["fast"], "drain": true,
		"desc": "专克快攻：每次触发多消耗敌方快攻 1 次出手。"
	},
	"tt_loop": {
		"name": "前冲弧圈球", "type": "spin", "cost": 25, "zone": ["mid"],
		"actions": 3, "interval": 1.5, "push": 1.5, "heavy": true,
		"desc": "强力前冲，推力最大，但被反拉与控台克制。"
	},
	"tt_spin": {
		"name": "加转弧圈球", "type": "spin", "cost": 25, "zone": ["mid", "far"],
		"actions": 3, "interval": 1.6, "push": 1.2, "heavy": true, "drain": true,
		"desc": "强旋转压制：被命中的单位额外掉 1 次出手。"
	},
	"tt_defense": {
		"name": "正手反拉", "type": "counter", "cost": 25, "zone": ["mid"],
		"actions": 2, "interval": 1.0, "push": 1.3, "reflect": ["spin"],
		"desc": "专克罗圈与扣杀：借力把敌方推力加倍反推。"
	},
	"tt_backhand_counter": {
		"name": "反手反拉", "type": "counter", "cost": 25, "zone": ["mid"],
		"actions": 2, "interval": 1.0, "push": 1.1, "reflect": ["fast"],
		"desc": "专克快攻与侧翼来球，反推并小幅支援相邻路。"
	},
	"tt_smash": {
		"name": "正手扣杀", "type": "counter", "cost": 30, "zone": ["mid", "far"],
		"actions": 1, "interval": 2.6, "push": 2.0, "heavy": true, "smash_detonate": true,
		"desc": "一击终结：炸弹已在我方半场推进时，直接推到敌方底线引爆。"
	},
	"tt_tactic": {
		"name": "霸王拧", "type": "counter", "cost": 35, "zone": ["near", "mid"],
		"actions": 2, "interval": 1.3, "push": 1.6, "heavy": true, "ignore_control": true,
		"desc": "无视控台压制强行起板，猛推炸弹。"
	}
}

const DECK := [
	"tt_sub", "tt_main", "tt_rip", "tt_short", "tt_long", "tt_serve", "tt_tear",
	"tt_loop", "tt_spin", "tt_defense", "tt_backhand_counter", "tt_smash", "tt_tactic"
]

const LEVELS := {
	"CH0-B01": {
		"name": "街头挑战 · 小孩哥", "hp": 110, "ability": "kid",
		"special": "童子功：快攻多 1 次出手、出手更快，2 秒一波往你半场砸",
		"hint": "他会用低费快攻抢推炸弹。前面放摆短/劈长拖慢他，中路放反拉借力反推。",
		"opening": [["tt_sub", 0, 0], ["tt_main", 1, 0], ["tt_rip", 2, 0]]
	},
	"CH0-B02": {
		"name": "街头挑战 · 小区大爷", "hp": 150, "ability": "elder",
		"special": "极致球感：正面硬砸弧圈/扣杀会被他借力反推",
		"hint": "他单位少但卸力极强。别硬砸，用发球和摆短/劈长耗他次数，再用霸王拧破局。",
		"opening": [["tt_long", 0, 5], ["tt_defense", 1, 2], ["tt_serve", 2, 5]]
	}
}

# ---------------------------------------------------------------- 战场状态

var level_id := "CH0-B01"
var phase := "deploy"
var damage_in := 0
var damage_out := 0
var auto_tick := true
var auto_refresh := true
var ui_enabled := true
var speed_multiplier := 1.0

var player_hp := PLAYER_MAX_HP
var enemy_hp := 110
var player_stamina := START_STAMINA
var enemy_stamina := 40
var battle_time := 0.0
var end_reason := ""

var board := {}
# 全场共用一颗主炸弹：pos 负=我方半场，正=敌方半场；timer 定时；lane 固定在中路
var bomb_pos := 0.0
var bomb_timer := BOMB_TIMER
var bomb_lane := 1
var boom_time := 0.0
# 引爆后的重生冷却：>0 时炸弹不在场，推力不作用，倒计时结束后放下一颗新炸弹
var bomb_cooldown := 0.0
# 炸弹视觉位置（缓动用，避免每次推力直接瞬移）
var bomb_vis_x := 0.0

var hand: Array = []
var draw_pile: Array = []
var discard: Array = []
var selected_card := -1
var log_lines: Array = []
var feedback := ""
var exits := {"player": 0, "enemy": 0}

var enemy_deploy_timer := ENEMY_DEPLOY_INTERVAL
var stamina_timer := 0.0

const TYPE_COLORS := {
	"fast": Color("#fb923c"),
	"spin": Color("#f472b6"),
	"control": Color("#34d399"),
	"counter": Color("#60a5fa")
}

# 3D 场景节点
const LANE_Z := [-1.2, 0.0, 1.2]
const SLOT_X0 := 1.15
const SLOT_X_STEP := 1.0

var battle_camera: Camera3D
var board_viewport: SubViewport
var board_container: SubViewportContainer
var table_mesh: MeshInstance3D
var panels := {"player": [], "enemy": []}
var panel_mats := {"player": [], "enemy": []}
var tokens := {"player": [], "enemy": []}
var bomb_node: MeshInstance3D
var bomb_material: StandardMaterial3D
var bomb_label: Label3D
var boom_node: MeshInstance3D
var boom_material: StandardMaterial3D

# 2D 覆盖层节点
var root: Control
var player_hp_label: Label
var enemy_hp_label: Label
var player_hp_bar: ProgressBar
var enemy_hp_bar: ProgressBar
var stamina_bar: ProgressBar
var stamina_label: Label
var timer_label: Label
var bomb_hud_label: Label
var log_label: Label
var feedback_label: Label
var level_label: Label
var hand_bar: HBoxContainer
var hand_buttons: Array = []
var icon_cache := {}
var level_buttons := {}
var start_button: Button
var auto_button: Button
var drag_label: Label

# 拖拽部署状态
var drag_card := -1
var drag_active := false
var drag_start := Vector2.ZERO


func _ready() -> void:
	if ui_enabled:
		_build_world()
		_build_ui()
	restart()


# ---------------------------------------------------------------- 状态初始化

func restart() -> void:
	phase = "deploy"
	battle_time = 0.0
	player_hp = PLAYER_MAX_HP
	enemy_hp = int(LEVELS[level_id]["hp"])
	player_stamina = START_STAMINA
	enemy_stamina = 40
	end_reason = ""
	selected_card = -1
	feedback = ""
	damage_in = 0
	damage_out = 0
	log_lines.clear()
	exits = {"player": 0, "enemy": 0}
	stamina_timer = 0.0
	enemy_deploy_timer = ENEMY_DEPLOY_INTERVAL
	board = {}
	for side in ["player", "enemy"]:
		var lanes: Array = []
		for lane in range(LANES):
			var rows: Array = []
			for row in range(ROWS):
				rows.append(null)
			lanes.append(rows)
		board[side] = lanes
	bomb_pos = 0.0
	bomb_timer = BOMB_TIMER
	bomb_lane = 1
	boom_time = 0.0
	bomb_cooldown = 0.0
	bomb_vis_x = 0.0
	hand = []
	draw_pile = []
	discard = []
	var pile: Array = DECK.duplicate()
	pile.shuffle()
	for i in range(mini(HAND_SIZE, pile.size())):
		hand.append(pile[i])
	for i in range(HAND_SIZE, pile.size()):
		draw_pile.append(pile[i])
	var opening: Array = LEVELS[level_id]["opening"]
	for entry in opening:
		_spawn(String(entry[0]), "enemy", int(entry[1]), int(entry[2]), false)
	_log("布阵阶段：%s" % String(LEVELS[level_id]["name"]))
	_log("敌方：%s" % String(LEVELS[level_id]["special"]))
	_log("全场一颗主炸弹，每 %.0f 秒引爆一次，推到底线立即引爆。" % BOMB_TIMER)
	set_feedback("点手牌 → 点桌面上的我方格子部署", true)
	_refresh()


func fedback_clear() -> void:
	feedback = ""


func _log(text: String) -> void:
	var prefix := "[布阵] " if phase == "deploy" else "[%4.1f]" % battle_time
	log_lines.append(prefix + text)
	if log_lines.size() > 8:
		log_lines.pop_front()


func set_feedback(text: String, ok: bool) -> void:
	feedback = text
	if feedback_label != null:
		feedback_label.text = text
		feedback_label.modulate = Color("#7fe4dd") if ok else Color("#fb7185")


# ---------------------------------------------------------------- 卡牌与部署

func card_cost(card_id: String, side := "player") -> int:
	var base := int(CARDS[card_id]["cost"])
	if side == "player" and String(CARDS[card_id]["type"]) == "fast":
		base = maxi(5, base - 2)  # 木棍：快攻便宜 2 点
	if side == "enemy" and String(LEVELS[level_id]["ability"]) == "kid" and String(CARDS[card_id]["type"]) == "fast":
		base = maxi(5, base - 3)
	return base


func card_actions(card_id: String, side := "player") -> int:
	var actions := int(CARDS[card_id].get("actions", 0))
	if actions <= 0:
		return 0
	if side == "player" and String(CARDS[card_id]["type"]) == "fast":
		actions += 1  # 木棍：快攻 +1 次出手
	if side == "enemy" and String(LEVELS[level_id]["ability"]) == "kid" and String(CARDS[card_id]["type"]) == "fast":
		actions += 1
	return actions


func zone_of_row(row: int) -> String:
	for zone in ["near", "mid", "far"]:
		if row >= int(ZONE_ROWS[zone][0]) and row <= int(ZONE_ROWS[zone][1]):
			return zone
	return "mid"


func card_fits(card_id: String, row: int) -> bool:
	var zones: Array = CARDS[card_id]["zone"]
	return zones.has(zone_of_row(row))


func _spawn(card_id: String, side: String, lane: int, row: int, pay := true) -> bool:
	if not CARDS.has(card_id):
		return false
	var cost := card_cost(card_id, side)
	if pay:
		if side == "player":
			if player_stamina < cost:
				set_feedback("体力不足：%s 需要 %d" % [String(CARDS[card_id]["name"]), cost], false)
				return false
			player_stamina -= cost
		else:
			if enemy_stamina < cost:
				return false
			enemy_stamina -= cost
	var unit := {
		"card": card_id, "name": String(CARDS[card_id]["name"]), "side": side,
		"type": String(CARDS[card_id]["type"]), "lane": lane, "row": row,
		"actions": card_actions(card_id, side),
		"duration": float(CARDS[card_id].get("duration", 0.0)),
		"interval": float(CARDS[card_id].get("interval", 1.0)),
		"push": float(CARDS[card_id].get("push", 0.0)),
		"cooldown": 0.0, "alive": true
	}
	if String(LEVELS[level_id]["ability"]) == "kid" and side == "enemy" and unit.type == "fast":
		unit.interval = float(unit.interval) * 0.95
	var old = board[side][lane][row]
	if old != null:
		old.alive = false
		exits[side] = int(exits[side]) + 1
		# 主动换阵覆盖：玩家替换旧单位时返还部分体力（设计 §4.2 第 4 种退场）
		if side == "player":
			var refund := int(card_cost(String(old.card), "player") * SWAP_REFUND)
			player_stamina = mini(STAMINA_MAX, player_stamina + refund)
			_log("换阵覆盖：%s 退场，返还 %d 点体力" % [String(old.name), refund])
	board[side][lane][row] = unit
	var entry_push := float(CARDS[card_id].get("entry_push", 0.0))
	if entry_push > 0.0 and phase == "battle":
		_push(side, lane, entry_push, unit)
	_log("%s %s → %s·%s" % ["我方" if side == "player" else "敌方", unit.name, ["上", "中", "下"][lane], ZONE_NAMES[zone_of_row(row)]])
	return true


func try_deploy(card_id: String, hand_index: int, lane: int, row: int) -> bool:
	if phase == "won" or phase == "lost":
		set_feedback("战斗已结束", false)
		return false
	if hand_index < 0 or hand_index >= hand.size() or String(hand[hand_index]) != card_id:
		return false
	if not card_fits(card_id, row):
		set_feedback("%s 只能放 %s" % [String(CARDS[card_id]["name"]), _zones_text(card_id)], false)
		return false
	if not _spawn(card_id, "player", lane, row, true):
		return false
	hand.remove_at(hand_index)
	discard.append(card_id)
	selected_card = -1
	_draw_one()
	_refresh()
	return true


func _zones_text(card_id: String) -> String:
	var names: Array = []
	for zone in CARDS[card_id]["zone"]:
		names.append(ZONE_NAMES[zone])
	return "/".join(names)


func _draw_one() -> void:
	if draw_pile.is_empty():
		if discard.is_empty():
			return
		draw_pile = discard.duplicate()
		discard.clear()
		draw_pile.shuffle()
	hand.append(String(draw_pile.pop_front()))


func auto_deploy() -> int:
	var count := 0
	# 第一波：每路先补一张最佳应对，避免全部挤到同一路；优先放攻击型单位
	for lane in range(LANES):
		var enemy_types := _lane_enemy_types(lane)
		var pick := _pick_hand_card(lane, enemy_types, -1, true)
		if pick[0] >= 0:
			if try_deploy(String(hand[pick[0]]), pick[0], lane, int(pick[1])):
				count += 1
	# 第二波：剩余空位继续按打分填（允许控台辅助）
	for lane in range(LANES):
		var enemy_types := _lane_enemy_types(lane)
		for row in range(ROWS):
			if board["player"][lane][row] != null:
				continue
			var pick := _pick_hand_card(lane, enemy_types, row, false)
			if pick[0] >= 0:
				if try_deploy(String(hand[pick[0]]), pick[0], lane, int(pick[1])):
					count += 1
	_refresh()
	if count == 0:
		set_feedback("没有可部署的牌或空位", false)
	else:
		set_feedback("自动布阵：部署 %d 张" % count, true)
	return count


func _lane_enemy_types(lane: int) -> Array:
	var types: Array = []
	for row in range(ROWS):
		var foe = board["enemy"][lane][row]
		if foe != null and foe.alive:
			types.append(String(foe.type))
	return types


# 从手牌选一张：index 为手牌序号，row 为建议落点（-1 表示由卡面区域自行找位）
func _pick_hand_card(lane: int, enemy_types: Array, row_hint: int, attacker_first: bool) -> Array:
	var best_index := -1
	var best_row := -1
	var best_score := -999.0
	for i in range(hand.size()):
		var card_id := String(hand[i])
		if player_stamina < card_cost(card_id, "player"):
			continue
		var row := row_hint
		if row < 0:
			row = _first_fitting_row(card_id, lane)
		elif not card_fits(card_id, row):
			continue
		if row < 0:
			continue
		var score := _deploy_score(card_id, enemy_types)
		if attacker_first and String(CARDS[card_id]["type"]) == "control":
			score -= 1.0
		if score > best_score:
			best_score = score
			best_index = i
			best_row = row
	return [best_index, best_row]


func _first_fitting_row(card_id: String, lane: int) -> int:
	for row in range(ROWS):
		if board["player"][lane][row] == null and card_fits(card_id, row):
			return row
	return -1


# 自动布阵打分：克制本路敌方类型加分；同区站位给基础分。
func _deploy_score(card_id: String, enemy_types: Array) -> float:
	var my_type := String(CARDS[card_id]["type"])
	var score := 1.0
	for foe_type in enemy_types:
		var mult := float(COUNTER[my_type].get(foe_type, 1.0))
		if mult > 1.0:
			score += 1.5 * mult
		# 防守视角：敌方类型打我方类型的克制倍率，被克制要扣分
		var foe_table: Dictionary = COUNTER[foe_type]
		var taken := float(foe_table.get(my_type, 1.0))
		if taken > 1.2:
			score -= 1.5 * taken
		# 反拉类的借力反射：被打时反推对应类型
		var reflect: Array = CARDS[card_id].get("reflect", [])
		if reflect.has(foe_type):
			score += 2.5
	if enemy_types.is_empty():
		score += 0.5
	return score


# ---------------------------------------------------------------- 战斗推进

func start_battle() -> void:
	if phase != "deploy":
		return
	phase = "battle"
	battle_time = 0.0
	bomb_timer = BOMB_TIMER
	_log("开战：双方招式推动全场主炸弹")
	_refresh()


func tick(delta: float) -> void:
	if phase != "battle":
		return
	var step := minf(delta, 0.1)
	var elapsed := 0.0
	while elapsed < delta and phase == "battle":
		_step(step)
		elapsed += step
	_refresh()


func _process(delta: float) -> void:
	if auto_tick:
		tick(delta)
	_tick_boom(delta)
	_update_bomb_visual(delta)


func _update_bomb_visual(delta: float) -> void:
	var target_x := bomb_pos / BOMB_RANGE * 7.15
	bomb_vis_x = move_toward(bomb_vis_x, target_x, delta * 10.0)
	if bomb_node != null:
		bomb_node.visible = bomb_cooldown <= 0.0
		bomb_node.position = Vector3(bomb_vis_x, 0.42, LANE_Z[bomb_lane])
	_update_bomb_countdown()


# 炸弹倒计时反馈：头顶剩余秒数 + 临爆变色 / 脉冲 / 自发光转红，制造压迫感
func _update_bomb_countdown() -> void:
	if bomb_label == null:
		return
	if bomb_cooldown > 0.0:
		bomb_label.visible = false
		return
	bomb_label.visible = true
	var remain := maxf(0.0, bomb_timer)
	bomb_label.text = str(ceili(remain))
	var col := Color("#7fe4dd")
	if remain <= 2.0:
		col = Color("#fb7185")
	elif remain <= 4.0:
		col = Color("#fbbf24")
	bomb_label.modulate = col
	# 最后 2 秒球体轻微脉冲跳动
	var pulse := 1.0
	if remain <= 2.0:
		pulse = 1.0 + 0.12 * sin(Time.get_ticks_msec() * 0.012)
	bomb_node.scale = Vector3(pulse, pulse, pulse)
	# 球体自发光随临爆升温转红
	if bomb_material != null:
		bomb_material.emission_enabled = true
		bomb_material.emission = col
		bomb_material.emission_energy_multiplier = 0.25 + (1.0 - remain / BOMB_TIMER) * 0.5


func _step(delta: float) -> void:
	battle_time += delta
	stamina_timer += delta
	if stamina_timer >= REGEN_INTERVAL:
		stamina_timer -= REGEN_INTERVAL
		player_stamina = mini(STAMINA_MAX, player_stamina + REGEN_AMOUNT)
		enemy_stamina = mini(STAMINA_MAX, enemy_stamina + ENEMY_REGEN_AMOUNT)

	# 炸弹冷却与计时：引爆后隔几秒放下一颗新炸弹，期间不推球
	if bomb_cooldown > 0.0:
		bomb_cooldown -= delta
		if bomb_cooldown <= 0.0:
			bomb_cooldown = 0.0
			bomb_timer = BOMB_TIMER
			_log("新炸弹放到中线，双方重新推球")
	else:
		bomb_timer = bomb_timer - delta
		if bomb_timer <= 0.0:
			_detonate("timer")

	# 双方单位出手
	for side in ["player", "enemy"]:
		for lane in range(LANES):
			for row in range(ROWS):
				var unit = board[side][lane][row]
				if unit == null or not unit.alive:
					continue
				_advance_unit(unit, delta)
		if phase != "battle":
			return

	# 敌方补位
	enemy_deploy_timer -= delta
	if enemy_deploy_timer <= 0.0:
		enemy_deploy_timer += ENEMY_DEPLOY_INTERVAL
		_enemy_deploy()

	if battle_time >= BATTLE_LIMIT:
		_end_by_time()


func _advance_unit(unit, delta: float) -> void:
	if unit.type == "control":
		unit.duration = float(unit.duration) - delta
		_control_tick(unit, delta)
		if unit.duration <= 0.0:
			_exit(unit, "持续时间结束")
		return
	unit.cooldown = float(unit.cooldown) - delta
	if float(unit.cooldown) > 0.0:
		return
	var target = _target_for(unit)
	_press(unit, target)
	unit.actions = int(unit.actions) - 1
	if int(unit.actions) <= 0:
		_exit(unit, "出手次数耗尽")
		return
	var interval := float(unit.interval)
	interval *= _interval_mult(unit)
	unit.cooldown = interval


func _control_tick(unit, delta: float) -> void:
	var resource := int(CARDS[unit.card].get("resource", 0))
	if resource > 0:
		var timer_key := "resource_timer"
		if not unit.has(timer_key):
			unit[timer_key] = float(CARDS[unit.card].get("resource_interval", 3.0))
		unit[timer_key] = float(unit[timer_key]) - delta
		if float(unit[timer_key]) <= 0.0:
			unit[timer_key] = float(CARDS[unit.card].get("resource_interval", 3.0))
			if unit.side == "player":
				player_stamina = mini(STAMINA_MAX, player_stamina + resource)
			else:
				enemy_stamina = mini(STAMINA_MAX, enemy_stamina + resource)


func _target_for(unit):
	var enemy_side := "enemy" if unit.side == "player" else "player"
	var lane := int(unit.lane)
	# 本路优先
	var target = _lane_target(enemy_side, lane)
	if target != null:
		return target
	# 本路敌方全空：多余攻势向相邻路偏移支援（设计 §2.2）
	for alt in [lane - 1, lane + 1]:
		if alt >= 0 and alt < LANES:
			target = _lane_target(enemy_side, alt)
			if target != null:
				return target
	return null


func _lane_target(side: String, lane: int):
	# 近台 → 远台依次找活着的目标
	for row in range(ROWS):
		var other = board[side][lane][row]
		if other != null and other.alive:
			return other
	return null


func _interval_mult(unit) -> float:
	var mult := 1.0
	var enemy_side := "enemy" if unit.side == "player" else "player"
	var lane := int(unit.lane)
	for row in range(ROWS):
		var other = board[enemy_side][lane][row]
		if other == null or not other.alive or other.type != "control":
			continue
		if bool(CARDS[other.card].get("ignore_control", false)):
			continue
		var debuff: Dictionary = CARDS[other.card].get("debuff", {})
		if debuff.is_empty():
			continue
		if String(debuff.get("type", "")) != String(unit.type):
			continue
		mult *= float(debuff.get("interval_mult", 1.0))
	return mult


func _push(side: String, lane: int, amount: float, unit = null) -> void:
	# 炸弹重生冷却期间场上无球，推力不作用
	if bomb_cooldown > 0.0:
		return
	if lane < 0 or lane >= LANES or amount == 0.0:
		return
	var sign_dir := 1.0 if side == "player" else -1.0
	bomb_pos = bomb_pos + amount * sign_dir
	_check_bomb()


func _press(unit, target) -> void:
	var lane := int(unit.lane)
	var push := float(unit.push)
	# 正手联动：同路有另一个正手招式
	if float(CARDS[unit.card].get("forehand_synergy", 0.0)) > 0.0 and _lane_has_forehand(unit):
		push += float(CARDS[unit.card]["forehand_synergy"])
	# 克制倍率
	var mult := 1.0
	if target != null:
		var table: Dictionary = COUNTER[unit.type]
		mult = float(table.get(String(target.type), 1.0))
		if mult > 1.0:
			_log("%s 克制 %s（推力 x%.1f）" % [unit.name, target.name, mult])
		# 克制压制（设计 §4.2-3）：明显克制命中时打断守方、削出手次数；
		# 自带 drain 的卡（快撕/加转弧圈）走同一套削次数，不叠加；控台单位免疫直接压制
		if target.type != "control" and mult >= COUNTER_SUPPRESS_MULT and int(target.actions) > 0:
			target.actions = int(target.actions) - COUNTER_SUPPRESS_DRAIN
			_log("%s 克制压制 %s，削 %d 次出手" % [unit.name, target.name, COUNTER_SUPPRESS_DRAIN])
			if int(target.actions) <= 0:
				_exit(target, "被克制招式逼退")
	push *= mult
	# 控台压制
	push *= _debuff_ratio(unit)
	# 敌方反拉类借力反推
	_reflect(unit, target, push)
	# 大爷的极致球感：正面硬砸弧圈/扣杀会被卸力反推
	if String(LEVELS[level_id]["ability"]) == "elder" and unit.side == "player" and bool(CARDS[unit.card].get("heavy", false)):
		var guardian = _first_lane_unit("enemy", lane)
		if guardian != null:
			var back := push * 0.5
			push -= back
			_push("enemy", lane, back)
			_log("%s 卸力反推 %.1f 格" % [guardian.name, back])
	# 转不转发球：来方本路第一次进攻吃转，被发球方反推一半力度
	var defender_side := "enemy" if unit.side == "player" else "player"
	var serve = _lane_reverse_serve(defender_side, lane)
	if serve != null:
		serve["reversed"] = true
		var back := push * 0.5
		_push(defender_side, lane, back)
		_log("%s 吃转：反推 %.1f 格" % [String(serve.name), back])
	_push(unit.side, lane, push)
	# 扣杀：炸弹已在敌方半场时直接推到底线引爆
	if bool(CARDS[unit.card].get("smash_detonate", false)):
		if unit.side == "player" and bomb_pos > 0.5:
			bomb_pos = BOMB_RANGE
			_check_bomb()
		elif unit.side == "enemy" and bomb_pos < -0.5:
			bomb_pos = -BOMB_RANGE
			_check_bomb()


func _lane_reverse_serve(side: String, lane: int):
	for row in range(ROWS):
		var u = board[side][lane][row]
		if u != null and u.alive and bool(CARDS[u.card].get("reverse_first", false)) and not u.has("reversed"):
			return u
	return null


func _lane_has_forehand(unit) -> bool:
	for row in range(ROWS):
		var other = board[unit.side][int(unit.lane)][row]
		if other == null or not other.alive or other == unit:
			continue
		if String(CARDS[other.card]["name"]).begins_with("正手"):
			return true
	return false


func _debuff_ratio(unit) -> float:
	var ratio := 1.0
	var enemy_side := "enemy" if unit.side == "player" else "player"
	for row in range(ROWS):
		var other = board[enemy_side][int(unit.lane)][row]
		if other == null or not other.alive or other.type != "control":
			continue
		if bool(CARDS[unit.card].get("ignore_control", false)):
			continue
		var debuff: Dictionary = CARDS[other.card].get("debuff", {})
		if debuff.is_empty():
			continue
		if String(debuff.get("type", "")) == String(unit.type):
			ratio *= float(debuff.get("ratio", 1.0))
			_log("%s 被 %s 控台压制，推力 x%.1f" % [unit.name, other.name, ratio])
	return ratio


func _reflect(unit, target, push: float) -> float:
	# 反拉类单位在被打时借力：把自己这一点推力反推回去
	if target == null:
		return 0.0
	if target.type != "counter":
		return 0.0
	var kinds: Array = CARDS[target.card].get("reflect", [])
	if not kinds.has(String(unit.type)):
		return 0.0
	if int(target.actions) <= 0:
		return 0.0
	var back := push * float(target.push) * 0.5
	_push(target.side, int(unit.lane), back)
	target.actions = int(target.actions) - 1
	_log("%s 借力反推 %.1f 格" % [target.name, back])
	if int(target.actions) <= 0:
		_exit(target, "反制次数耗尽")
	return back


func _first_lane_unit(side: String, lane: int):
	for row in range(ROWS):
		var other = board[side][lane][row]
		if other != null and other.alive:
			return other
	return null


func _exit(unit, reason: String) -> void:
	if not unit.alive:
		return
	unit.alive = false
	board[unit.side][int(unit.lane)][int(unit.row)] = null
	exits[unit.side] = int(exits[unit.side]) + 1
	_log("%s %s 收拍（%s）" % ["我方" if unit.side == "player" else "敌方", unit.name, reason])


func _check_bomb() -> void:
	if bomb_pos >= BOMB_RANGE:
		_detonate("baseline_enemy")
	elif bomb_pos <= -BOMB_RANGE:
		_detonate("baseline_player")


func _detonate(reason: String) -> void:
	var hit_side := ""
	if reason == "timer":
		if bomb_pos > 0.3:
			_damage_side("enemy", BOMB_DAMAGE, "炸弹定时引爆")
			hit_side = "enemy"
		elif bomb_pos < -0.3:
			_damage_side("player", BOMB_DAMAGE, "炸弹定时引爆")
			hit_side = "player"
		else:
			_log("炸弹在中线震荡，无人受伤")
	elif reason == "baseline_enemy":
		_damage_side("enemy", BASELINE_DAMAGE, "炸弹被推到底线")
		hit_side = "enemy"
	elif reason == "baseline_player":
		_damage_side("player", BASELINE_DAMAGE, "炸弹被推到底线")
		hit_side = "player"
	# 局部冲击波：震掉受击方前排近台单位的部分出手（设计 §3.2）
	_shockwave(hit_side)
	play_explosion()
	bomb_pos = 0.0
	bomb_cooldown = BOMB_RESPAWN
	if bomb_node != null:
		bomb_node.visible = false
	_log("炸弹引爆，%.0f 秒后放下一颗新球" % BOMB_RESPAWN)


func _shockwave(side: String) -> void:
	if side == "":
		return
	for lane in range(LANES):
		for row in ZONE_ROWS["near"]:
			var u = board[side][lane][row]
			if u == null or not u.alive:
				continue
			if u.type == "control":
				continue
			u.actions = int(u.actions) - SHOCKWAVE_DRAIN
			_log("冲击波：%s 前排 %s 受震，掉 %d 次出手" % ["我方" if side == "player" else "敌方", String(u.name), SHOCKWAVE_DRAIN])
			if int(u.actions) <= 0:
				_exit(u, "冲击波震退场")


func play_explosion() -> void:
	boom_time = 0.6
	if boom_node != null:
		boom_node.visible = true
		boom_node.position = bomb_node.position if bomb_node != null else Vector3.ZERO


func _tick_boom(delta: float) -> void:
	if boom_time <= 0.0:
		return
	boom_time = maxf(0.0, boom_time - delta)
	if boom_node == null or boom_material == null:
		return
	var t := 1.0 - boom_time / 0.6
	var scale := 0.6 + t * 2.6
	boom_node.scale = Vector3(scale, scale, scale)
	boom_material.albedo_color = Color(1.0, 0.62, 0.18, boom_time / 0.6)
	if boom_time <= 0.0:
		boom_node.visible = false


func _damage_side(side: String, amount: int, source: String) -> void:
	if side == "player":
		player_hp -= amount
		damage_in += amount
		_log("%s：我方生命 -%d（剩 %d）" % [source, amount, maxi(0, player_hp)])
		if player_hp <= 0:
			phase = "lost"
			end_reason = "生命归零"
			set_feedback("战斗失败：生命归零", false)
	else:
		enemy_hp -= amount
		damage_out += amount
		_log("%s：敌方生命 -%d（剩 %d）" % [source, amount, maxi(0, enemy_hp)])
		if enemy_hp <= 0:
			phase = "won"
			end_reason = "敌方生命归零"
			set_feedback("挑战成功：对手生命归零", true)


func _end_by_time() -> void:
	phase = "won" if player_hp > enemy_hp else "lost"
	end_reason = "90 秒到，按剩余生命判定"
	_log("90 秒到：我方 %d / 敌方 %d" % [maxi(0, player_hp), maxi(0, enemy_hp)])
	set_feedback("时间到：%s" % ("我方血量更高" if phase == "won" else "敌方血量更高"), phase == "won")


func _enemy_deploy() -> void:
	if enemy_stamina <= 0:
		return
	var ability := String(LEVELS[level_id]["ability"])
	var order: Array = DECK.duplicate()
	if ability == "kid":
		order.sort_custom(func(a, b): return _type_rank_kid(String(a)) < _type_rank_kid(String(b)))
	else:
		order.sort_custom(func(a, b): return _type_rank_elder(String(a)) < _type_rank_elder(String(b)))
	for card_id in order:
		if enemy_stamina < card_cost(String(card_id), "enemy"):
			continue
		var slot = _enemy_slot_for(String(card_id))
		if slot == null:
			continue
		return _spawn(String(card_id), "enemy", int(slot[0]), int(slot[1]), true)


func _type_rank_kid(card_id: String) -> int:
	return 0 if String(CARDS[card_id]["type"]) == "fast" else 1


func _type_rank_elder(card_id: String) -> int:
	var t := String(CARDS[card_id]["type"])
	if t == "control":
		return 0
	if t == "counter":
		return 1
	return 2


func _enemy_slot_for(card_id: String):
	var zones: Array = CARDS[card_id]["zone"]
	var lane_order: Array = [1, 0, 2]
	for lane in lane_order:
		for zone in zones:
			for row in ZONE_ROWS[zone]:
				if board["enemy"][lane][int(row)] == null:
					return [lane, int(row)]
	return null


# ---------------------------------------------------------------- 3D 场景搭建

func _material(color: Color, emissive := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 0.5
	return material


func _slot_position(side: String, lane: int, row: int) -> Vector3:
	var sign := -1.0 if side == "player" else 1.0
	var x := sign * (SLOT_X0 + row * SLOT_X_STEP)
	return Vector3(x, 0.06, LANE_Z[lane])


func _build_world() -> void:
	# 3D 棋盘渲染进独立 SubViewport，固定在顶部带状区域，不与底部手牌重叠
	board_viewport = SubViewport.new()
	board_viewport.size = Vector2i(1240, 300)
	board_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# 独立 3D 世界：否则棋子/炸弹挂在共享主世界里，主相机也会把它们再渲染一遍，界面下方漏出第二套阵型
	board_viewport.own_world_3d = true
	var world := board_viewport

	# 独立环境光 + 平行光（布阵场景可能脱离主世界单独打开）
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#0a1322")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8fa9c8")
	env.ambient_light_energy = 0.7
	env_node.environment = env
	world.add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 25, 0)
	sun.light_color = Color("#ffe6c4")
	sun.light_energy = 1.0
	world.add_child(sun)

	battle_camera = Camera3D.new()
	battle_camera.fov = 40.0
	world.add_child(battle_camera)
	battle_camera.look_at_from_position(Vector3(0.0, 7.5, 0.8), Vector3.ZERO, Vector3.UP)
	battle_camera.current = true

	# 台面底座外框（深色木托）
	var frame := MeshInstance3D.new()
	var frame_box := BoxMesh.new()
	frame_box.size = Vector3(15.9, 0.18, 5.0)
	frame.mesh = frame_box
	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = Color("#1a212c")
	frame_mat.roughness = 0.8
	frame.material_override = frame_mat
	frame.position = Vector3(0.0, -0.22, 0.0)
	world.add_child(frame)

	# 台面（淡橡木）
	table_mesh = MeshInstance3D.new()
	var table_box := BoxMesh.new()
	table_box.size = Vector3(15.5, 0.3, 4.6)
	table_mesh.mesh = table_box
	var table_mat := StandardMaterial3D.new()
	table_mat.albedo_color = Color("#b98f5f")
	table_mat.roughness = 0.8
	table_mesh.material_override = table_mat
	table_mesh.position = Vector3(0.0, -0.15, 0.0)
	world.add_child(table_mesh)

	# 中线发光球网
	var center_line := MeshInstance3D.new()
	var center_box := BoxMesh.new()
	center_box.size = Vector3(0.1, 0.03, 4.2)
	center_line.mesh = center_box
	var net_mat := StandardMaterial3D.new()
	net_mat.albedo_color = Color("#8fdcff")
	net_mat.emission_enabled = true
	net_mat.emission = Color("#6fc9ff")
	net_mat.emission_energy_multiplier = 0.9
	center_line.material_override = net_mat
	center_line.position = Vector3(0.0, 0.02, 0.0)
	world.add_child(center_line)

	# 车道分隔凹槽（上/中/下三路边界）
	for groove_z in [-0.6, 0.6]:
		var groove := MeshInstance3D.new()
		var groove_box := BoxMesh.new()
		groove_box.size = Vector3(14.6, 0.02, 0.06)
		groove.mesh = groove_box
		var groove_mat := StandardMaterial3D.new()
		groove_mat.albedo_color = Color("#1f2d3a")
		groove_mat.roughness = 0.85
		groove.material_override = groove_mat
		groove.position = Vector3(0.0, 0.02, groove_z)
		world.add_child(groove)

	# 槽位面板 + 点选 Area3D
	for side in ["player", "enemy"]:
		panels[side] = []
		panel_mats[side] = []
		tokens[side] = []
		for lane in range(LANES):
			var lane_panels: Array = []
			var lane_mats: Array = []
			var lane_tokens: Array = []
			for row in range(ROWS):
				var panel := MeshInstance3D.new()
				var box := BoxMesh.new()
				box.size = Vector3(0.9, 0.1, 1.1)
				panel.mesh = box
				var mat := StandardMaterial3D.new()
				mat.albedo_color = _zone_color(zone_of_row(row))
				panel.material_override = mat
				panel.position = _slot_position(side, lane, row)
				panel.set_meta("side", side)
				panel.set_meta("lane", lane)
				panel.set_meta("row", row)
				world.add_child(panel)

				var area := Area3D.new()
				var shape := BoxShape3D.new()
				shape.size = Vector3(0.9, 0.8, 1.1)
				var collision := CollisionShape3D.new()
				collision.shape = shape
				area.add_child(collision)
				area.position = panel.position
				area.set_meta("side", side)
				area.set_meta("lane", lane)
				area.set_meta("row", row)
				world.add_child(area)

				lane_panels.append(panel)
				lane_mats.append(mat)
				lane_tokens.append(null)
			panels[side].append(lane_panels)
			panel_mats[side].append(lane_mats)
			tokens[side].append(lane_tokens)

	# 主炸弹
	bomb_node = MeshInstance3D.new()
	var bomb_sphere := SphereMesh.new()
	bomb_sphere.radius = 0.42
	bomb_sphere.height = 0.84
	bomb_node.mesh = bomb_sphere
	bomb_material = StandardMaterial3D.new()
	bomb_material.albedo_color = Color("#262c34")
	bomb_material.metallic = 0.6
	bomb_material.roughness = 0.35
	bomb_node.material_override = bomb_material
	bomb_node.position = Vector3(0.0, 0.42, LANE_Z[1])
	world.add_child(bomb_node)

	# 引信火花
	var fuse := MeshInstance3D.new()
	var fuse_sphere := SphereMesh.new()
	fuse_sphere.radius = 0.1
	fuse_sphere.height = 0.2
	fuse.mesh = fuse_sphere
	fuse.material_override = _material(Color("#fbbf24"), true)
	fuse.position = Vector3(0.0, 0.5, 0.0)
	bomb_node.add_child(fuse)

	# 炸弹脚下金色光环
	var aura := MeshInstance3D.new()
	var aura_ring := TorusMesh.new()
	aura_ring.inner_radius = 0.52
	aura_ring.outer_radius = 0.7
	aura.mesh = aura_ring
	var aura_mat := StandardMaterial3D.new()
	aura_mat.albedo_color = Color(1.0, 0.85, 0.3, 0.7)
	aura_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aura_mat.emission_enabled = true
	aura_mat.emission = Color(1.0, 0.78, 0.25)
	aura_mat.emission_energy_multiplier = 0.9
	aura.material_override = aura_mat
	aura.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	aura.position = Vector3(0.0, 0.08, 0.0)
	bomb_node.add_child(aura)

	# 左右方向小箭头（提示拔河推力方向）
	for dir in [-1, 1]:
		var arrow := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.09
		cone.height = 0.24
		arrow.mesh = cone
		arrow.material_override = _material(Color("#f4f8ff"), true)
		arrow.position = Vector3(0.58 * dir, 0.0, 0.0)
		arrow.rotation_degrees = Vector3(0.0, 0.0, 90.0 * dir)
		bomb_node.add_child(arrow)

	# 头顶倒计时标签：剩余引爆时间 + 临爆变色/脉冲
	bomb_label = Label3D.new()
	bomb_label.position = Vector3(0.0, 0.95, 0.0)
	bomb_label.font_size = 28
	bomb_label.pixel_size = 0.012
	bomb_label.outline_size = 8
	bomb_label.outline_modulate = Color("#0b1220")
	bomb_label.billboard = 1
	bomb_label.text_horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bomb_label.text_vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bomb_node.add_child(bomb_label)

	# 爆炸冲击环
	boom_node = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.9
	ring.outer_radius = 1.1
	boom_node.mesh = ring
	boom_material = StandardMaterial3D.new()
	boom_material.albedo_color = Color(1.0, 0.62, 0.18, 0.0)
	boom_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	boom_material.emission_enabled = true
	boom_material.emission = Color(1.0, 0.5, 0.15)
	boom_node.material_override = boom_material
	boom_node.visible = false
	world.add_child(boom_node)

	# 背景上浮余烬粒子（舞台氛围）
	var embers := CPUParticles3D.new()
	embers.amount = 36
	embers.lifetime = 4.0
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	embers.emission_sphere_radius = 6.0
	embers.direction = Vector3(0.0, 1.0, 0.0)
	embers.spread = 25.0
	embers.gravity = Vector3(0.0, 0.12, 0.0)
	embers.initial_velocity_min = 0.15
	embers.initial_velocity_max = 0.5
	embers.scale_amount_min = 0.04
	embers.scale_amount_max = 0.1
	embers.color = Color(1.0, 0.72, 0.35, 0.65)
	embers.emitting = true
	world.add_child(embers)

	# 两侧斜射光束（半透明加法面片模拟舞台光，无碰撞体，不影响槽位射线）
	for beam_side in [-1, 1]:
		var beam := MeshInstance3D.new()
		var beam_mesh := PlaneMesh.new()
		beam_mesh.size = Vector2(5.0, 11.0)
		beam.mesh = beam_mesh
		var beam_mat := StandardMaterial3D.new()
		beam_mat.albedo_color = Color(0.62, 0.78, 1.0, 0.05)
		beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		beam_mat.emission_enabled = true
		beam_mat.emission = Color(0.55, 0.72, 1.0)
		beam_mat.emission_energy_multiplier = 0.35
		beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		beam.material_override = beam_mat
		beam.position = Vector3(beam_side * 4.5, 3.0, -1.5)
		beam.rotation_degrees = Vector3(18.0, beam_side * 24.0, beam_side * 12.0)
		world.add_child(beam)


func _zone_color(zone: String) -> Color:
	match zone:
		"near":
			return Color("#3a5168")
		"mid":
			return Color("#33475c")
		"far":
			return Color("#2c3e50")
	return Color("#33475c")


func _hand_index_of(ctrl: Control) -> int:
	# 悬停命中通常落到手牌内部的 orb / Label 等最深层子控件；meta 挂在根卡片上，需要沿父链回溯
	var cur: Node = ctrl
	while cur != null:
		if cur.has_meta("hand_index"):
			return int(cur.get_meta("hand_index"))
		cur = cur.get_parent()
	return -1


func _is_button(ctrl: Control) -> bool:
	var cur: Node = ctrl
	while cur != null:
		if cur is Button:
			return true
		cur = cur.get_parent()
	return false


func _input(event: InputEvent) -> void:
	if battle_camera == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_on_mouse_down(event)
		else:
			_on_mouse_up(event)
	elif event is InputEventMouseMotion and drag_card >= 0:
		if not drag_active and event.position.distance_to(drag_start) > 10.0:
			drag_active = true
			_refresh()
		if drag_active:
			var drag_cid := String(hand[drag_card])
			_show_drag_label(String(CARDS[drag_cid]["name"]), event.position)


func _on_mouse_down(event: InputEventMouseButton) -> void:
	var hovered := get_viewport().gui_get_hovered_control()
	var hidx := _hand_index_of(hovered)
	if hidx >= 0:
		drag_card = hidx
		drag_start = event.position
		drag_active = false
		return
	# 点在其他可交互按钮上时不穿透； inert 容器/标签不拦截，继续走 3D 槽位射线
	if _is_button(hovered):
		return
	var slot := _pick_slot(event.position)
	if not slot.is_empty():
		_on_slot(String(slot["side"]), int(slot["lane"]), int(slot["row"]))


func _on_mouse_up(event: InputEventMouseButton) -> void:
	if drag_card < 0:
		return
	if drag_active:
		var hovered_up := get_viewport().gui_get_hovered_control()
		var over_gui := _is_button(hovered_up) and _hand_index_of(hovered_up) < 0
		if not over_gui:
			var slot := _pick_slot(event.position)
			if not slot.is_empty() and String(slot["side"]) == "player":
				try_deploy(String(hand[drag_card]), drag_card, int(slot["lane"]), int(slot["row"]))
	else:
		_on_hand_pressed(drag_card)
	drag_card = -1
	drag_active = false
	_hide_drag_label()
	_refresh()


func _pick_slot(screen_pos: Vector2) -> Dictionary:
	var local := _to_viewport_local(screen_pos)
	var ray_origin: Vector3 = battle_camera.project_ray_origin(local)
	var ray_dir: Vector3 = battle_camera.project_ray_normal(local)
	# 相机挂在独立 SubViewport 内，用它所属的 3D 世界做射线；回退到根世界兜底
	var view_world: World3D = battle_camera.get_world_3d() if battle_camera != null else get_world_3d()
	if view_world == null:
		view_world = get_world_3d()
	var space := view_world.direct_space_state
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_dir * 30.0)
	query.collide_with_areas = true
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return {}
	var collider: Object = hit.collider
	if collider == null or not collider.has_meta("side"):
		return {}
	return {
		"side": String(collider.get_meta("side")),
		"lane": int(collider.get_meta("lane")),
		"row": int(collider.get_meta("row"))
	}


func _to_viewport_local(screen_pos: Vector2) -> Vector2:
	if board_container == null or board_viewport == null:
		return screen_pos
	var csize := board_container.size
	if csize.x <= 0.0 or csize.y <= 0.0:
		return screen_pos
	var vlocal := (screen_pos - board_container.global_position) * Vector2(board_viewport.size) / csize
	return vlocal


func _show_drag_label(card_name: String, pos: Vector2) -> void:
	if drag_label == null:
		return
	drag_label.text = card_name
	drag_label.position = pos + Vector2(12, -10)
	drag_label.visible = true


func _hide_drag_label() -> void:
	if drag_label != null:
		drag_label.visible = false


func _token_color(unit) -> Color:
	return TYPE_COLORS.get(String(unit.type), Color("#e2e8f0"))


func _get_type_icon(card_type: String) -> Texture2D:
	if icon_cache.has(card_type):
		return icon_cache[card_type]
	var img := Image.new()
	var err := img.load("res://assets/icons/icon_%s.png" % card_type)
	var tex: Texture2D = null
	if err == OK:
		tex = ImageTexture.create_from_image(img)
	icon_cache[card_type] = tex
	return tex


func _sync_tokens() -> void:
	if tokens.is_empty():
		return
	for side in ["player", "enemy"]:
		for lane in range(LANES):
			for row in range(ROWS):
				var unit = board[side][lane][row]
				var token = tokens[side][lane][row]
				if unit == null:
					if token != null:
						token.queue_free()
						tokens[side][lane][row] = null
					continue
				if token == null:
					token = Sprite3D.new()
					token.texture = _get_type_icon(String(unit.type))
					token.billboard = 1
					token.position = _slot_position(side, lane, row) + Vector3(0.0, 0.30, 0.0)
					token.scale = Vector3(0.42, 0.42, 0.42)
					board_viewport.add_child(token)
					# 卡片式方形底座
					var base := MeshInstance3D.new()
					var tile := BoxMesh.new()
					tile.size = Vector3(0.72, 0.06, 0.92)
					base.mesh = tile
					base.material_override = StandardMaterial3D.new()
					base.position = Vector3(0.0, -0.26, 0.0)
					token.add_child(base)
					# 头顶卡牌名标签
					var label := Label3D.new()
					label.name = "unit_label"
					label.position = Vector3(0.0, 0.68, 0.0)
					label.font_size = 30
					label.pixel_size = 0.014
					label.outline_size = 8
					label.outline_modulate = Color("#0b1220")
					label.billboard = 1
					token.add_child(label)
					tokens[side][lane][row] = token
				token.texture = _get_type_icon(String(unit.type))
				var base_mat: StandardMaterial3D = token.get_child(0).material_override
				var type_color: Color = TYPE_COLORS[String(unit.type)]
				base_mat.albedo_color = Color("#2b3a4d")
				base_mat.roughness = 0.7
				base_mat.emission_enabled = true
				base_mat.emission = type_color
				base_mat.emission_energy_multiplier = 0.12
				var unit_label: Label3D = token.get_node_or_null("unit_label")
				if unit_label != null:
					var suffix := "" if int(unit.actions) <= 0 else " ×%d" % int(unit.actions)
					unit_label.text = String(unit.name) + suffix
					unit_label.modulate = Color("#f1f8ff")
				# 扣顶小标识：靠近相机一侧压低棋子高度，远台略小，形成纵深
				var depth_scale := 1.0 - row * 0.03
				token.scale = Vector3(0.42 * depth_scale, 0.42 * depth_scale, 0.42 * depth_scale)


func _sync_board_visuals() -> void:
	if panels.is_empty():
		return
	_sync_tokens()

	var card_id := ""
	var highlight_idx := selected_card
	if highlight_idx < 0 and drag_active and drag_card >= 0 and drag_card < hand.size():
		highlight_idx = drag_card
	if highlight_idx >= 0 and highlight_idx < hand.size():
		card_id = String(hand[highlight_idx])

	for lane in range(LANES):
		for row in range(ROWS):
			for side in ["player", "enemy"]:
				var mat: StandardMaterial3D = panel_mats[side][lane][row]
				var unit = board[side][lane][row]
				if side == "player" and card_id != "":
					if not card_fits(card_id, row):
						mat.albedo_color = Color("#0e1622")
					elif unit != null:
						mat.albedo_color = Color("#6b5318")
					else:
						mat.albedo_color = Color("#17594a")
				elif unit != null:
					mat.albedo_color = _token_color(unit).darkened(0.55)
				else:
					mat.albedo_color = _zone_color(zone_of_row(row))

	# 炸弹位置：沿 X 轴压到对应半场格子，固定中路；颜色保持金属深色，不随半场切换
	var bomb_x := bomb_vis_x
	if bomb_node != null:
		bomb_node.position = Vector3(bomb_x, 0.42, LANE_Z[bomb_lane])


# ---------------------------------------------------------------- 2D 覆盖层

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# 覆盖层整体不拦截鼠标；PASS 表示根容器自身不吞事件，子控件（手牌/按钮）仍正常接收，点空白可穿透到 3D 槽位
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(root)

	var main := VBoxContainer.new()
	main.position = Vector2(20, 14)
	main.size = Vector2(1240, 692)
	main.add_theme_constant_override("separation", 8)
	root.add_child(main)

	var header := PanelContainer.new()
	header.add_theme_stylebox_override("panel", _flat(Color("#142233e6"), Color("#2c4258"), 12))
	var header_vbox := VBoxContainer.new()
	header_vbox.add_theme_constant_override("separation", 8)
	header.add_child(header_vbox)
	main.add_child(header)

	# 顶部第一行：关卡切换 + 能力说明 + 计时
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	header_vbox.add_child(top)
	for id in LEVELS.keys():
		var button := Button.new()
		button.text = String(LEVELS[id]["name"]).split(" · ")[1]
		button.custom_minimum_size = Vector2(96, 34)
		button.add_theme_stylebox_override("normal", _flat(Color("#1c2c40"), Color("#31495c"), 8))
		button.add_theme_stylebox_override("hover", _flat(Color("#243850"), Color("#3f5d78"), 8))
		button.pressed.connect(_on_level.bind(String(id)))
		level_buttons[id] = button
		top.add_child(button)
	# BOSS 能力金色徽章
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(22, 22)
	var badge_mat := _flat(Color("#b8860b"), Color("#fbbf24"), 11)
	badge.add_theme_stylebox_override("panel", badge_mat)
	var badge_dot := Label.new()
	badge_dot.text = "★"
	badge_dot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_dot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_dot.add_theme_font_size_override("font_size", 13)
	badge_dot.add_theme_color_override("font_color", Color("#fff7d6"))
	badge.add_child(badge_dot)
	top.add_child(badge)
	level_label = Label.new()
	level_label.add_theme_font_size_override("font_size", 15)
	level_label.add_theme_color_override("font_color", Color("#d9f1ff"))
	top.add_child(level_label)
	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(top_spacer)
	timer_label = Label.new()
	timer_label.add_theme_font_size_override("font_size", 15)
	timer_label.add_theme_color_override("font_color", Color("#a9bfd1"))
	top.add_child(timer_label)
	bomb_hud_label = Label.new()
	bomb_hud_label.add_theme_font_size_override("font_size", 15)
	top.add_child(bomb_hud_label)

	# 顶部第二行：双方生命条 + 我方体力条
	var status := HBoxContainer.new()
	status.add_theme_constant_override("separation", 16)
	header_vbox.add_child(status)
	player_hp_label = Label.new()
	player_hp_label.custom_minimum_size = Vector2(150, 22)
	status.add_child(player_hp_label)
	player_hp_bar = _make_bar(PLAYER_MAX_HP, Color("#4ade80"))
	status.add_child(player_hp_bar)
	enemy_hp_label = Label.new()
	enemy_hp_label.custom_minimum_size = Vector2(150, 22)
	status.add_child(enemy_hp_label)
	enemy_hp_bar = _make_bar(int(LEVELS[level_id]["hp"]), Color("#f87171"))
	status.add_child(enemy_hp_bar)
	var st_spacer := Control.new()
	st_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_child(st_spacer)
	stamina_label = Label.new()
	stamina_label.add_theme_color_override("font_color", Color("#7dd3fc"))
	status.add_child(stamina_label)
	stamina_bar = ProgressBar.new()
	stamina_bar.max_value = STAMINA_MAX
	stamina_bar.custom_minimum_size = Vector2(160, 18)
	stamina_bar.show_percentage = false
	stamina_bar.add_theme_stylebox_override("background", _flat(Color("#1b2a3a"), Color("#31495c"), 3))
	var st_fill := StyleBoxFlat.new()
	st_fill.bg_color = Color("#38bdf8")
	st_fill.set_corner_radius_all(3)
	stamina_bar.add_theme_stylebox_override("fill", st_fill)
	status.add_child(stamina_bar)

	# 棋盘 3D 视口（固定在顶部带状区域，手牌在其下方，互不遮挡）
	board_container = SubViewportContainer.new()
	board_container.custom_minimum_size = Vector2(1240, 300)
	board_container.stretch = true
	board_container.add_child(board_viewport)
	main.add_child(board_container)

	# 手牌
	var hand_row := HBoxContainer.new()
	hand_row.add_theme_constant_override("separation", 12)
	var hand_left_spacer := Control.new()
	hand_left_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_row.add_child(hand_left_spacer)
	main.add_child(hand_row)
	hand_bar = hand_row
	for i in range(HAND_SIZE):
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(150, 140)
		card.set_meta("hand_index", i)
		var vbox := VBoxContainer.new()
		vbox.alignment = VBoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 4)
		card.add_child(vbox)
		var orb := PanelContainer.new()
		orb.custom_minimum_size = Vector2(64, 64)
		orb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var orb_tex := TextureRect.new()
		orb_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		orb_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		orb_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		orb.add_child(orb_tex)
		vbox.add_child(orb)
		var name_l := Label.new()
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(name_l)
		var cost_wrap := PanelContainer.new()
		cost_wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var cost_l := Label.new()
		cost_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_wrap.add_child(cost_l)
		vbox.add_child(cost_wrap)
		var action_l := Label.new()
		action_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(action_l)
		var pips_wrap := PanelContainer.new()
		pips_wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var pips_l := Label.new()
		pips_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pips_wrap.add_child(pips_l)
		vbox.add_child(pips_wrap)
		card.set_meta("refs", {"orb": orb, "orb_tex": orb_tex, "name": name_l, "cost": cost_l, "cost_wrap": cost_wrap, "action": action_l, "pips": pips_l, "pips_wrap": pips_wrap})
		hand_buttons.append(card)
		hand_row.add_child(card)
	var hand_right_spacer := Control.new()
	hand_right_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_row.add_child(hand_right_spacer)

	drag_label = Label.new()
	drag_label.add_theme_font_size_override("font_size", 16)
	drag_label.add_theme_color_override("font_color", Color("#eaf6ff"))
	drag_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_label.visible = false
	root.add_child(drag_label)

	# 底部操作：反馈文字居左，两枚大胶囊按钮纵向排在右下
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	main.add_child(bottom)
	feedback_label = Label.new()
	feedback_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	feedback_label.add_theme_font_size_override("font_size", 15)
	bottom.add_child(feedback_label)
	var btn_col := VBoxContainer.new()
	btn_col.add_theme_constant_override("separation", 10)
	btn_col.alignment = VBoxContainer.ALIGNMENT_END
	bottom.add_child(btn_col)
	auto_button = Button.new()
	auto_button.text = "自动布阵"
	auto_button.custom_minimum_size = Vector2(180, 50)
	auto_button.add_theme_font_size_override("font_size", 16)
	auto_button.add_theme_stylebox_override("normal", _flat(Color("#2a3646"), Color("#46586c"), 16))
	auto_button.add_theme_stylebox_override("hover", _flat(Color("#35455a"), Color("#5d7488"), 16))
	auto_button.pressed.connect(func(): auto_deploy())
	btn_col.add_child(auto_button)
	start_button = Button.new()
	start_button.text = "开战 / 重开"
	start_button.custom_minimum_size = Vector2(180, 50)
	start_button.add_theme_font_size_override("font_size", 16)
	start_button.add_theme_stylebox_override("normal", _flat(Color("#173a36"), Color("#34d399"), 16))
	start_button.add_theme_stylebox_override("hover", _flat(Color("#1e4a43"), Color("#6ee7b7"), 16))
	start_button.pressed.connect(_on_start)
	btn_col.add_child(start_button)

	log_label = Label.new()
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.custom_minimum_size = Vector2(1220, 56)
	log_label.add_theme_font_size_override("font_size", 13)
	log_label.add_theme_color_override("font_color", Color("#a9bfd1"))
	main.add_child(log_label)


func _flat(bg: Color, border: Color, radius := 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	return s


func _make_bar(max_value: float, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = max_value
	bar.custom_minimum_size = Vector2(150, 18)
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", _flat(Color("#1b2a3a"), Color("#31495c"), 3))
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


func _on_slot(side: String, lane: int, row: int) -> void:
	if side != "player":
		return
	if selected_card < 0:
		var unit = board["player"][lane][row]
		set_feedback("先点一张手牌" if unit == null else "%s：剩余 %d 次" % [unit.name, int(unit.actions)], unit != null)
		return
	var card_id := String(hand[selected_card])
	try_deploy(card_id, selected_card, lane, row)


func _on_hand_pressed(index: int) -> void:
	if index >= hand.size():
		return
	selected_card = -1 if selected_card == index else index
	_refresh()


func _on_level(id: String) -> void:
	level_id = id
	restart()


func _on_start() -> void:
	if phase == "deploy":
		start_battle()
	else:
		restart()


# 顶部 HUD 炸弹倒计时读数（与 3D 头顶标签互为冗余）
func _update_bomb_hud() -> void:
	if bomb_hud_label == null:
		return
	if phase == "deploy":
		bomb_hud_label.text = "布阵阶段"
		bomb_hud_label.add_theme_color_override("font_color", Color("#64748b"))
		return
	if bomb_cooldown > 0.0:
		bomb_hud_label.text = "炸弹重生中"
		bomb_hud_label.add_theme_color_override("font_color", Color("#64748b"))
		return
	var remain := maxf(0.0, bomb_timer)
	var col := Color("#7fe4dd")
	if remain <= 2.0:
		col = Color("#fb7185")
	elif remain <= 4.0:
		col = Color("#fbbf24")
	bomb_hud_label.text = "引爆 %ds" % ceili(remain)
	bomb_hud_label.add_theme_color_override("font_color", col)


func _refresh() -> void:
	if not ui_enabled or player_hp_label == null:
		return
	player_hp_label.text = "我方生命 %d / %d" % [maxi(0, player_hp), PLAYER_MAX_HP]
	enemy_hp_label.text = "敌方生命 %d" % maxi(0, enemy_hp)
	player_hp_bar.max_value = PLAYER_MAX_HP
	player_hp_bar.value = maxi(0, player_hp)
	enemy_hp_bar.max_value = int(LEVELS[level_id]["hp"])
	enemy_hp_bar.value = maxi(0, enemy_hp)
	stamina_bar.value = player_stamina
	stamina_label.text = "体力 %d / %d" % [player_stamina, STAMINA_MAX]
	timer_label.text = "回合 %.1f / %.0f s  %s" % [battle_time, BATTLE_LIMIT, _phase_text()]
	_update_bomb_hud()
	level_label.text = String(LEVELS[level_id]["special"])
	for id in level_buttons:
		level_buttons[id].modulate = Color("#7fe4dd") if String(id) == level_id else Color.WHITE

	_sync_board_visuals()

	for i in range(hand_buttons.size()):
		var card: PanelContainer = hand_buttons[i]
		var refs: Dictionary = card.get_meta("refs")
		if i >= hand.size():
			card.visible = false
			continue
		card.visible = true
		var card_id := String(hand[i])
		var def: Dictionary = CARDS[card_id]
		var selected := i == selected_card
		var cost := card_cost(card_id, "player")
		var afford := player_stamina >= cost
		var type_color: Color = TYPE_COLORS[String(def["type"])]
		var max_actions := card_actions(card_id, "player")
		var action_line := "出手 %d 次" % max_actions if max_actions > 0 else "持续 %.0fs" % float(def.get("duration", 0.0))
		var pips_line := "%d/%d" % [max_actions, max_actions] if max_actions > 0 else "—"
		var name_l: Label = refs["name"]
		var cost_l: Label = refs["cost"]
		var cost_wrap: PanelContainer = refs["cost_wrap"]
		var action_l: Label = refs["action"]
		var pips_l: Label = refs["pips"]
		var pips_wrap: PanelContainer = refs["pips_wrap"]
		var orb: PanelContainer = refs["orb"]
		var orb_tex: TextureRect = refs["orb_tex"]
		orb_tex.texture = _get_type_icon(String(def["type"]))
		orb.add_theme_stylebox_override("panel", _flat(Color("#16222f"), type_color.darkened(0.25), 28))
		name_l.text = String(def["name"])
		cost_l.text = "%d费" % cost
		action_l.text = "%s · %s" % [action_line, ZONE_NAMES[String(def["zone"][0])]]
		pips_l.text = pips_line
		name_l.add_theme_color_override("font_color", Color("#edf7ff") if afford else Color("#697887"))
		action_l.add_theme_color_override("font_color", Color("#c9d8e6") if afford else Color("#697887"))
		var badge_bg := Color("#fbbf24") if afford else Color("#4a4436")
		cost_wrap.add_theme_stylebox_override("panel", _flat(badge_bg, Color("#d9a416"), 8))
		cost_l.add_theme_color_override("font_color", Color("#231a05") if afford else Color("#8a8064"))
		var strip_bg := Color("#3a3320") if afford else Color("#222a31")
		pips_wrap.add_theme_stylebox_override("panel", _flat(strip_bg, Color("#fbbf24").darkened(0.3), 6))
		pips_l.add_theme_color_override("font_color", Color("#fde68a") if afford else Color("#6b5f43"))
		name_l.add_theme_font_size_override("font_size", 15)
		cost_l.add_theme_font_size_override("font_size", 12)
		action_l.add_theme_font_size_override("font_size", 12)
		pips_l.add_theme_font_size_override("font_size", 12)
		var bg := Color("#1c2c40") if afford else Color("#131d2b")
		if selected:
			bg = bg.lightened(0.10)
		var border := type_color if selected else (type_color.darkened(0.35) if afford else Color("#24313b"))
		var border_w := 2 if selected else 1
		var normal := _flat(bg, border, 12)
		normal.set_border_width_all(border_w)
		card.add_theme_stylebox_override("panel", normal)
	log_label.text = "\n".join(log_lines)
	if feedback_label != null:
		feedback_label.text = feedback


func _phase_text() -> String:
	match phase:
		"deploy":
			return "布阵中"
		"battle":
			return "对战中"
		"won":
			return "胜利"
		"lost":
			return "失败"
	return ""


# ---------------------------------------------------------------- 存档点（调试用）

func state_text() -> String:
	return "hp %d/%d · bomb %.1f · stamina %d" % [
		player_hp, enemy_hp, bomb_pos, player_stamina
	]
