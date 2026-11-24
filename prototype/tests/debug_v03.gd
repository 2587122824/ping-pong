extends SceneTree

# 调试：单局 dump 状态轨迹，定位 V0.3 失守原因。
const LEVEL := "CH0-B01"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene = load("res://formation_battle_v03.tscn")
	var battle: Variant = scene.instantiate()
	battle.ui_enabled = false
	battle.auto_tick = false
	root.add_child(battle)
	await process_frame
	battle.level_id = LEVEL
	battle.restart()
	battle.auto_deploy()
	print("opening: player units=%d stamina=%.0f hand=%d" % [_count(battle, "player"), battle.player_stamina, battle.hand.size()])
	_dump_board(battle)
	battle.start_battle()
	var steps := 0
	var next_dump := 0.0
	while String(battle.phase) == "battle" and steps < 1200:
		battle.tick(0.1)
		if steps % 5 == 0:
			battle.auto_deploy()
		if battle.battle_time >= next_dump:
			var bp := "bomb=%.1f" % battle.bomb_pos
			print("t=%5.1f P_HP=%3d E_HP=%3d P_ST=%4.0f E_ST=%4.0f P_U=%d E_U=%d %s" % [
				battle.battle_time, battle.player_hp, battle.enemy_hp,
				battle.player_stamina, battle.enemy_stamina,
				_count(battle, "player"), _count(battle, "enemy"), bp])
			next_dump += 3.0
		steps += 1
	print("phase=%s reason=%s damage_in=%d damage_out=%d" % [battle.phase, battle.end_reason, battle.damage_in, battle.damage_out])
	battle.queue_free()
	quit()


func _count(battle, side: String) -> int:
	var count := 0
	for lane in range(3):
		for row in range(7):
			if battle.board[side][lane][row] != null:
				count += 1
	return count


func _dump_board(battle) -> void:
	for side in ["player", "enemy"]:
		var parts: Array = []
		for lane in range(3):
			var row_parts: Array = []
			for row in range(7):
				var u = battle.board[side][lane][row]
				row_parts.append(String(u.card) if u != null else ".")
			parts.append("L%d[%s]" % [lane, " ".join(row_parts)])
		print(side + ": " + "  ".join(parts))
