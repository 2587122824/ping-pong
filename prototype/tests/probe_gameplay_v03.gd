extends SceneTree

# V0.3 玩法诊断探针：按时间片统计单位密度 / 空场断档 / 炸弹推进深度 / 体力水位。
# 运行：
# & $env:LOCALAPPDATA\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path prototype --script res://tests/probe_gameplay_v03.gd

const LEVELS := ["CH0-B01", "CH0-B02"]
const RUNS := 6
const MAX_SIM_SECONDS := 120.0
const STEP := 0.1
const SLOTS := 21


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene = load("res://formation_battle_v03.tscn")
	var battle: Variant = scene.instantiate()
	battle.ui_enabled = false
	battle.auto_tick = false
	root.add_child(battle)
	await process_frame

	for level_index in range(LEVELS.size()):
		var level: String = LEVELS[level_index]
		var agg := {"pu": 0.0, "eu": 0.0, "empty_both": 0, "samples": 0,
			"p_st": 0.0, "e_st": 0.0, "max_enemy": 0.0, "max_player": 0.0,
			"p_hp": 0, "e_hp": 0, "wins": 0}
		for run_index in range(RUNS):
			seed(900000 + level_index * 100 + run_index)
			battle.level_id = level
			battle.restart()
			battle.auto_deploy()
			battle.start_battle()
			var steps := 0
			while String(battle.phase) == "battle" and steps < int(MAX_SIM_SECONDS / STEP):
				battle.tick(STEP)
				if steps % 5 == 0:
					battle.auto_deploy()
				if steps % 20 == 0:
					var pu := _count(battle, "player")
					var eu := _count(battle, "enemy")
					agg["pu"] += pu
					agg["eu"] += eu
					agg["p_st"] += battle.player_stamina
					agg["e_st"] += battle.enemy_stamina
					if pu == 0 and eu == 0:
						agg["empty_both"] += 1
					agg["max_enemy"] = maxf(agg["max_enemy"], battle.bomb_pos)
					agg["max_player"] = minf(agg["max_player"], battle.bomb_pos)
					agg["samples"] += 1
				steps += 1
			if String(battle.phase) == "won":
				agg["wins"] += 1
			agg["p_hp"] += maxi(0, battle.player_hp)
			agg["e_hp"] += maxi(0, battle.enemy_hp)
		var n: int = int(agg["samples"])
		print("== %s ==" % level)
		print("  胜场 %d/%d  均残血 P=%d E=%d" % [agg["wins"], RUNS,
			int(agg["p_hp"] / RUNS), int(agg["e_hp"] / RUNS)])
		print("  均在场 P=%.1f/21 (%.0f%%)  E=%.1f/21 (%.0f%%)" % [
			agg["pu"] / n, 100.0 * agg["pu"] / n / SLOTS,
			agg["eu"] / n, 100.0 * agg["eu"] / n / SLOTS])
		print("  双方皆空的时间片占比 %.0f%%" % [100.0 * agg["empty_both"] / n])
		print("  体力均水位 P=%.0f E=%.0f" % [agg["p_st"] / n, agg["e_st"] / n])
		print("  炸弹最深推到敌半场 %.1f / 我方半场 %.1f（满格 %.0f）" % [
			agg["max_enemy"], agg["max_player"], battle.BOMB_RANGE])

	# 克制压制探针：攻方克制守方（mult>1.3）时，守方是否被削次数/逼退
	battle.level_id = "CH0-B01"
	battle.restart()
	_clear(battle)
	battle._spawn("tt_loop", "player", 1, 2, false)   # spin 克 fast 1.3
	battle._spawn("tt_sub", "enemy", 1, 0, false)
	var attacker = battle.board["player"][1][2]
	var defender = battle.board["enemy"][1][0]
	var actions_before: int = int(defender.actions)
	battle.start_battle()
	battle._press(attacker, defender)
	print("== 克制压制探针 ==")
	print("  spin 攻 fast：守方次数 %d → %d（明显克制削 1 次出手）" % [
		actions_before, int(defender.actions)])
	print("  守方存活=%s" % defender.alive)

	battle.queue_free()
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
