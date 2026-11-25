extends SceneTree

# V0.3 新规则专项探针：控台压制扣时长 / 三种连携 / 跨路 debuff 跟随 / 高压期定时。
# 运行：
# & $env:LOCALAPPDATA\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64.exe --headless --path prototype --script res://tests/probe_rules_v03.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene = load("res://formation_battle_v03.tscn")
	var battle: Variant = scene.instantiate()
	battle.ui_enabled = false
	battle.auto_tick = false
	root.add_child(battle)
	await process_frame
	battle.level_id = "CH0-B01"
	battle.restart()

	# 1. 克制压制：快攻打控台（fast→control=1.3）缩短控台 1.5s 持续时间
	_wipe(battle)
	battle._spawn("tt_main", "player", 1, 0, false)
	var atk = battle.board["player"][1][0]
	battle._spawn("tt_short", "enemy", 1, 0, false)
	var ctrl = battle.board["enemy"][1][0]
	var dur_before: float = float(ctrl.duration)
	battle.start_battle()
	battle._press(atk, ctrl)
	assert(float(ctrl.duration) <= dur_before - 1.4, "控台被压制缩短 1.5s 时长: %.2f" % float(ctrl.duration))
	print("[ok] 控台压制扣时长 %.2f -> %.2f" % [dur_before, float(ctrl.duration)])

	# 2. 调动起板：同路己方控台 + 弧圈重击，重击推力 +25%
	battle.restart()
	battle.level_id = "CH0-B01"
	_wipe(battle)
	battle._spawn("tt_short", "player", 2, 0, false)
	battle._spawn("tt_loop", "player", 2, 2, false)
	var loop = battle.board["player"][2][2]
	battle.bomb_pos = 0.0
	battle.start_battle()
	battle._press(loop, null)
	var push_with: float = battle.bomb_pos
	# 无控台对照
	battle.restart()
	battle.level_id = "CH0-B01"
	_wipe(battle)
	battle._spawn("tt_loop", "player", 2, 2, false)
	var loop2 = battle.board["player"][2][2]
	battle.bomb_pos = 0.0
	battle.start_battle()
	battle._press(loop2, null)
	var push_without: float = battle.bomb_pos
	assert(push_with > push_without * 1.2, "调动起板推力 +25%%: 有控台 %.2f / 无控台 %.2f" % [push_with, push_without])
	print("[ok] 调动起板 有控台 %.2f 无控台 %.2f" % [push_with, push_without])

	# 3. 双拍连击：同路正手 + 反手，间隔 -10%
	battle.restart()
	battle.level_id = "CH0-B01"
	_wipe(battle)
	battle._spawn("tt_main", "player", 1, 0, false)
	var fh = battle.board["player"][1][0]
	battle._spawn("tt_rip", "player", 1, 1, false)
	assert(battle._lane_has_forehand("player", 1) and battle._lane_has_backhand("player", 1), "同路正手反手识别")
	var interval: float = float(fh.interval) * battle._interval_mult(fh) * 0.9
	assert(absf(interval - float(fh.interval) * 0.9) < 0.001, "双拍间隔减免生效: %.3f" % interval)
	print("[ok] 双拍连击 间隔 %.3f" % interval)

	# 4. 防守反击链：近台牵制 + 中台反拉，反推力 +20%
	battle.restart()
	battle.level_id = "CH0-B01"
	_wipe(battle)
	battle._spawn("tt_sub", "enemy", 1, 0, false)
	var near = battle.board["enemy"][1][0]
	battle._spawn("tt_backhand_counter", "enemy", 1, 2, false)
	var counter = battle.board["enemy"][1][2]
	battle._spawn("tt_main", "player", 1, 0, false)
	var foe = battle.board["player"][1][0]
	battle.bomb_pos = 0.0
	battle.start_battle()
	battle._press(foe, counter)
	# 反击链判定成立
	assert(battle._lane_has_near_pressure("enemy", 1), "近台牵制识别")
	print("[ok] 防守反击链判定成立")

	# 5. 跨路支援 debuff 跟随：弧圈索敌到相邻路后，按目标路扫控台压制
	battle.restart()
	battle.level_id = "CH0-B01"
	_wipe(battle)
	battle._spawn("tt_loop", "player", 1, 2, false)
	var loose = battle.board["player"][1][2]
	battle._spawn("tt_short", "enemy", 0, 0, false)
	# 目标在 0 路，debuff 应跟随到 0 路生效
	var ratio: float = battle._debuff_ratio(loose, 0)
	assert(ratio == 0.5, "跨路 debuff 跟随目标路: %.2f" % ratio)
	var mult: float = battle._interval_mult(loose, 0)
	assert(mult == 1.5, "跨路间隔拖慢跟随目标路: %.2f" % mult)
	print("[ok] 跨路 debuff 跟随 比率 %.2f 间隔 %.2f" % [ratio, mult])

	# 6. 终盘高压期：炸弹定时从 7.0 缩到 5.5
	battle.restart()
	battle.level_id = "CH0-B01"
	battle.battle_time = 60.0
	assert(absf(battle._bomb_timer_target() - 5.5) < 0.001, "高压期炸弹定时 5.5s")
	battle.battle_time = 5.0
	assert(absf(battle._bomb_timer_target() - 7.0) < 0.001, "常规期炸弹定时 7.0s")
	print("[ok] 三阶段定时 常规 7.0 / 高压 5.5")

	battle.queue_free()
	print("rules v0.3 probe ok")
	quit()


func _wipe(battle) -> void:
	for side in ["player", "enemy"]:
		for lane in range(3):
			for row in range(7):
				battle.board[side][lane][row] = null
