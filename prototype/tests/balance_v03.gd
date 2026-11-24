extends SceneTree

# V0.3 布阵平衡探针：自动布阵 + 战斗中自动补位，看两个街头 BOSS 的胜率与时长。
# 运行：
# & $env:LOCALAPPDATA\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path prototype --script res://tests/balance_v03.gd

const LEVELS := ["CH0-B01", "CH0-B02"]
const RUNS := 8
const MAX_SIM_SECONDS := 120.0
const STEP := 0.1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene = load("res://formation_battle_v03.tscn")
	var battle: Variant = scene.instantiate()
	battle.ui_enabled = false
	battle.auto_tick = false
	root.add_child(battle)
	await process_frame

	print("level,runs,wins,win_rate,avg_seconds,avg_player_hp,avg_enemy_hp,avg_player_units,avg_enemy_units")
	for level_index in range(LEVELS.size()):
		var level: String = LEVELS[level_index]
		var wins := 0
		var total_time := 0.0
		var left_player_hp := 0
		var left_enemy_hp := 0
		var left_player_units := 0
		var left_enemy_units := 0
		for run_index in range(RUNS):
			seed(800000 + level_index * 100 + run_index)
			battle.level_id = level
			battle.restart()
			battle.auto_deploy()
			battle.start_battle()
			var steps := 0
			while String(battle.phase) == "battle" and steps < int(MAX_SIM_SECONDS / STEP):
				battle.tick(STEP)
				if steps % 5 == 0:
					battle.auto_deploy()
				steps += 1
			if String(battle.phase) == "won":
				wins += 1
			total_time += battle.battle_time
			left_player_hp += maxi(0, battle.player_hp)
			left_enemy_hp += maxi(0, battle.enemy_hp)
			left_player_units += _count(battle, "player")
			left_enemy_units += _count(battle, "enemy")
		print("%s,%d,%d,%.2f,%.1f,%.1f,%.1f,%.1f,%.1f" % [
			level, RUNS, wins, float(wins) / float(RUNS),
			total_time / float(RUNS),
			float(left_player_hp) / float(RUNS),
			float(left_enemy_hp) / float(RUNS),
			float(left_player_units) / float(RUNS),
			float(left_enemy_units) / float(RUNS)
		])
	print("v0.3 balance run done")
	battle.queue_free()
	quit()


func _count(battle, side: String) -> int:
	var count := 0
	for lane in range(3):
		for row in range(7):
			if battle.board[side][lane][row] != null:
				count += 1
	return count
