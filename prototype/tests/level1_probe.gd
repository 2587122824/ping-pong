extends SceneTree

# 第一关（CH0-01）生命倍率探针：固定 4 只小怪阵型，扫 enemy_hp_multiplier，输出时长/胜率/阵亡。
# 运行：
# & $env:LOCALAPPDATA\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path prototype --script res://tests/level1_probe.gd
const DECKS := ["vanguard", "aero", "bastion"]
const RUNS := 8
const GAP := 30
const FORMATION := [
	{"card": "aero_004", "lane": 1, "row": 0},
	{"card": "aero_001", "lane": 0, "row": 0},
	{"card": "aero_002", "lane": 2, "row": 0},
	{"card": "aero_003", "lane": 1, "row": 1}
]
const MULTS := [1.3, 1.5, 1.6, 1.8]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene = load("res://formation_battle.tscn")
	var battle: Variant = scene.instantiate()
	battle.auto_tick = false
	battle.auto_refresh = false
	battle.ui_enabled = false
	battle.shuffle_on_reshuffle = true
	root.add_child(battle)
	await process_frame
	battle.level_definitions["CH0-01"]["formation"] = FORMATION
	print("hp_mult,deck,wins,runs,win_rate,avg_seconds,avg_lost_player,avg_lost_enemy,avg_left_player")
	for mult in MULTS:
		battle.level_definitions["CH0-01"]["enemy_hp_multiplier"] = float(mult)
		for deck_index in range(DECKS.size()):
			var deck_id: String = DECKS[deck_index]
			var wins := 0
			var total_time := 0.0
			var lost_player := 0
			var lost_enemy := 0
			var left_player := 0
			for run_index in range(RUNS):
				seed(940000 + deck_index * 1000 + run_index + int(mult * 10))
				battle.player_deck_id = deck_id
				battle.level_id = "CH0-01"
				battle.restart_battle()
				_shuffle_opening_hand(battle)
				battle.auto_deploy_formation()
				battle.start_battle()
				var steps := 0
				while String(battle.phase) == "battle" and steps < 1200:
					battle.tick(0.1)
					if steps % GAP == 0:
						battle.auto_reinforce_battle()
					steps += 1
				if String(battle.phase) == "won":
					wins += 1
				total_time += battle.battle_time
				lost_player += int(battle.units_lost["player"])
				lost_enemy += int(battle.units_lost["enemy"])
				left_player += battle._count_side_units("player")
			print("%.1f,%s,%d,%d,%.2f,%.1f,%.1f,%.1f,%.1f" % [
				mult, deck_id, wins, RUNS, float(wins) / float(RUNS),
				total_time / float(RUNS), float(lost_player) / float(RUNS),
				float(lost_enemy) / float(RUNS), float(left_player) / float(RUNS)
			])
	print("level1 mult done")
	battle.queue_free()
	quit()


func _shuffle_opening_hand(battle) -> void:
	var cards: Array = battle.player_hand.duplicate() + battle.player_draw_pile.duplicate()
	cards.shuffle()
	battle.player_hand = cards.slice(0, mini(5, cards.size()))
	battle.player_draw_pile = cards.slice(battle.player_hand.size())
	battle.selected_card_index = -1
	battle._refresh_hand()
