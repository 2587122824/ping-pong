extends SceneTree

# V0.3 实时布阵冒烟测试：无血量单位、炸弹推拉、克制、BOSS 能力、生命结算。
# 运行：
# & $env:LOCALAPPDATA\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path prototype --script res://tests/smoke_formation_v03.gd

const COSTS := {
	"tt_sub": 10, "tt_main": 15, "tt_rip": 15, "tt_short": 15, "tt_long": 15,
	"tt_serve": 15, "tt_tear": 20, "tt_loop": 25, "tt_spin": 25, "tt_defense": 25,
	"tt_backhand_counter": 25, "tt_smash": 30, "tt_tactic": 35
}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene = load("res://formation_battle_v03.tscn")
	assert(scene != null, "v0.3 scene loads")
	var battle: Variant = scene.instantiate()
	battle.ui_enabled = false
	battle.auto_tick = false
	root.add_child(battle)
	await process_frame

	# 牌组与费用
	assert(battle.DECK.size() == 13, "13-card single deck")
	for card_id in COSTS.keys():
		assert(battle.CARDS.has(card_id), "%s exists" % card_id)
		assert(int(battle.CARDS[card_id]["cost"]) == int(COSTS[card_id]), "%s cost matches V0.3 table" % card_id)
	assert(battle.card_cost("tt_sub", "player") == 8, "wooden stick knocks 2 off fast cards")
	assert(battle.card_actions("tt_sub", "player") == 4, "wooden stick adds one action to fast cards")
	assert(battle.card_actions("tt_loop", "player") == 3, "spin cards keep their action count")

	# 布阵与区域限制
	battle.level_id = "CH0-B01"
	battle.restart()
	assert(battle.phase == "deploy", "starts in deploy")
	assert(battle.player_hp == 100, "player hp 100")
	assert(battle.enemy_hp == 110, "kid boss hp 110")
	assert(_count(battle, "enemy") == 3, "kid opens with three units")
	assert(battle.hand.size() == 5, "hand of 5")
	var near_card_index := _ensure(battle, "tt_short")
	assert(battle.try_deploy("tt_short", near_card_index, 0, 0), "control card may sit in the near zone")
	assert(battle.board["player"][0][0] != null, "unit placed")
	assert(not battle.card_fits("tt_long", 0), "far-zone card cannot be placed in the near zone")
	assert(not battle.card_fits("tt_sub", 6), "near-zone card cannot be placed at the baseline")

	# 炸弹推动
	battle.restart()
	battle.level_id = "CH0-B01"
	var push_index := _ensure(battle, "tt_main")
	assert(battle.try_deploy("tt_main", push_index, 1, 0), "deploy a fast card mid lane")
	assert(battle.player_stamina == 100 - 13, "fast card costs 13 after the stick discount")
	battle.start_battle()
	battle.bomb_pos = 0.0
	var before: float = battle.bomb_pos
	# 清掉全部敌方单位，避免其他路推力混入共享炸弹
	for lane in range(3):
		for row in range(7):
			battle.board["enemy"][lane][row] = null
	battle.tick(0.1)
	assert(battle.bomb_pos > before, "fast card pushes the bomb toward the enemy half: %.2f" % battle.bomb_pos)
	assert(battle.bomb_pos > 0.9, "fast push is at least ~1 grid")

	# 定时引爆伤害
	battle.restart()
	battle.level_id = "CH0-B01"
	_clear(battle)
	battle.start_battle()
	var hp_before: int = battle.enemy_hp
	battle.bomb_pos = 2.0
	battle.bomb_timer = 0.05
	battle.tick(0.1)
	assert(battle.enemy_hp == hp_before - 15, "timer detonation hurts the side the bomb sits on: %d" % battle.enemy_hp)
	assert(absf(battle.bomb_pos) < 0.01, "bomb resets to the centre line: %.2f" % battle.bomb_pos)
	# 引爆后进入重生冷却：冷却期推球不作用，结束后放下一颗新炸弹
	assert(battle.bomb_cooldown > 0.0, "bomb enters respawn cooldown after detonation")
	battle._push("player", 0, 3.0)
	assert(absf(battle.bomb_pos) < 0.01, "push is suppressed during respawn cooldown")
	battle.tick(battle.BOMB_RESPAWN + 0.2)
	assert(battle.bomb_cooldown <= 0.0, "new bomb drops after respawn cooldown")

	# 推到底线立即引爆
	battle.restart()
	battle.level_id = "CH0-B01"
	_clear(battle)
	battle.start_battle()
	var push_hp: int = battle.player_hp
	battle._push("enemy", 0, 7.0)
	assert(battle.player_hp == push_hp - 22, "baseline detonation hits for 22: %d" % battle.player_hp)

	# 出手次数耗尽退场
	battle.restart()
	battle.level_id = "CH0-B01"
	_clear(battle)
	battle._spawn("tt_sub", "player", 0, 0, false)
	var unit = battle.board["player"][0][0]
	assert(int(unit.actions) == 4, "stick gives 快带 four swings")
	battle.start_battle()
	for lane in range(3):
		for row in range(7):
			var other = battle.board["enemy"][lane][row]
			if other != null:
				other.cooldown = 99.0
	battle.tick(0.1)
	assert(int(unit.actions) == 3, "one swing spends one action")
	battle.tick(6.0)
	assert(not unit.alive, "unit leaves after its actions run out")
	assert(battle.board["player"][0][0] == null, "slot frees up when the unit leaves")

	# 控台压制：摆短把弧圈推力减半
	battle.restart()
	battle.level_id = "CH0-B01"
	_clear(battle)
	battle._spawn("tt_loop", "player", 2, 2, false)
	battle._spawn("tt_short", "enemy", 2, 0, false)
	var loop_unit = battle.board["player"][2][2]
	assert(battle._debuff_ratio(loop_unit) == 0.5, "摆短 halves the spin push")
	assert(battle._interval_mult(loop_unit) == 1.5, "摆短 slows the spin interval")

	# 借力反推：反手反拉打快攻
	battle.restart()
	battle.level_id = "CH0-B01"
	_clear(battle)
	battle._spawn("tt_rip", "player", 1, 0, false)
	var fast_unit = battle.board["player"][1][0]
	battle._spawn("tt_backhand_counter", "enemy", 1, 2, false)
	var counter_unit = battle.board["enemy"][1][2]
	battle.bomb_pos = 0.0
	battle.start_battle()
	battle._press(fast_unit, counter_unit)
	assert(battle.bomb_pos < 1.0, "反手反拉 pushes back part of the fast shot: %.2f" % battle.bomb_pos)
	assert(int(counter_unit.actions) == 1, "borrowing spends one counter action")

	# 小孩哥童子功：敌方快攻多一次出手
	assert(battle.card_actions("tt_sub", "enemy") == 4, "kid fast cards get one extra action")

	# 大爷极致球感：硬砸弧圈被卸力
	battle.level_id = "CH0-B02"
	battle.restart()
	_clear(battle)
	assert(battle.enemy_hp == 150, "elder boss hp 150")
	battle._spawn("tt_loop", "player", 1, 2, false)
	var heavy = battle.board["player"][1][2]
	battle._spawn("tt_long", "enemy", 1, 5, false)
	var elder_unit = battle.board["enemy"][1][5]
	battle.start_battle()
	battle._press(heavy, elder_unit)
	assert(battle.bomb_pos < 1.5, "elder soft hands cut the spin push: %.2f" % battle.bomb_pos)

	# 生命归零结算
	battle.level_id = "CH0-B01"
	battle.restart()
	battle.start_battle()
	battle._damage_side("enemy", 500, "test")
	assert(String(battle.phase) == "won", "enemy hp zero wins")
	battle.restart()
	battle.start_battle()
	battle._damage_side("player", 500, "test")
	assert(String(battle.phase) == "lost", "player hp zero loses")

	# 时间到按血量判定
	battle.level_id = "CH0-B01"
	battle.restart()
	battle.start_battle()
	battle.player_hp = 80
	battle.enemy_hp = 40
	battle.battle_time = 89.99
	battle.tick(0.1)
	assert(String(battle.phase) == "won", "time limit compares hp")

	battle.queue_free()
	print("formation v0.3 smoke ok")
	quit()


func _clear(battle) -> void:
	for side in ["player", "enemy"]:
		for lane in range(3):
			for row in range(7):
				battle.board[side][lane][row] = null


func _count(battle, side: String) -> int:
	var count := 0
	for lane in range(3):
		for row in range(7):
			if battle.board[side][lane][row] != null:
				count += 1
	return count


func _ensure(battle, card_id: String) -> int:
	var index: int = battle.hand.find(card_id)
	if index >= 0:
		return index
	battle.hand[0] = card_id
	return 0
