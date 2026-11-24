extends SceneTree

# 调参对照：卡费倍率 × 布阵体力 × 战斗中补位冷却。
# 运行：
# & $env:LOCALAPPDATA\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path prototype --script res://tests/balance_tuning.gd

const DECKS := ["vanguard", "aero", "bastion"]
const LEVELS := ["CH0-01"]
const RUNS := 8
const MAX_SIM_SECONDS := 130.0
const STEP := 0.1

const CONFIGS := [
	{"name": "baseline_cost100", "cost": 1.0, "battle_cost": 1.0, "opening": 100, "opening_by_deck": {}, "cooldown": 0.0},
	{"name": "cost110", "cost": 1.1, "battle_cost": 1.0, "opening": 100, "opening_by_deck": {}, "cooldown": 0.0},
	{"name": "cost125", "cost": 1.25, "battle_cost": 1.0, "opening": 100, "opening_by_deck": {}, "cooldown": 0.0},
	{"name": "cost140", "cost": 1.4, "battle_cost": 1.0, "opening": 100, "opening_by_deck": {}, "cooldown": 0.0},
	{"name": "cost150", "cost": 1.5, "battle_cost": 1.0, "opening": 100, "opening_by_deck": {}, "cooldown": 0.0},
	{"name": "cost175", "cost": 1.75, "battle_cost": 1.0, "opening": 100, "opening_by_deck": {}, "cooldown": 0.0}
]


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

	print("config,deck,level,runs,wins,win_rate,avg_seconds,avg_lost_player,avg_lost_enemy")
	var totals := {}
	for config in CONFIGS:
		var config_name := String(config["name"])
		var config_wins := 0
		var config_games := 0
		var config_time := 0.0
		for deck_index in range(DECKS.size()):
			var deck_id: String = DECKS[deck_index]
			for level_index in range(LEVELS.size()):
				var level: String = LEVELS[level_index]
				var wins := 0
				var total_time := 0.0
				var lost_player := 0
				var lost_enemy := 0
				for run_index in range(RUNS):
					seed(910000 + deck_index * 1000 + level_index * 40 + run_index)
					battle.card_cost_multiplier = float(config["cost"])
					battle.battle_cost_multiplier = float(config["battle_cost"])
					var opening_map: Dictionary = config["opening_by_deck"]
					battle.opening_stamina = int(opening_map.get(deck_id, config["opening"]))
					battle.battle_reinforce_cooldown = float(config["cooldown"])
					battle.player_deck_id = deck_id
					battle.level_id = level
					battle.restart_battle()
					_shuffle_opening_hand(battle)
					battle.auto_deploy_formation()
					battle.start_battle()
					var steps := 0
					while String(battle.phase) == "battle" and steps < int(MAX_SIM_SECONDS / STEP):
						battle.tick(STEP)
						if steps % 3 == 0:
							battle.auto_reinforce_battle()
						steps += 1
					if String(battle.phase) == "won":
						wins += 1
						config_wins += 1
					config_games += 1
					total_time += battle.battle_time
					config_time += battle.battle_time
					lost_player += int(battle.units_lost["player"])
					lost_enemy += int(battle.units_lost["enemy"])
				print("%s,%s,%s,%d,%d,%.2f,%.1f,%.1f,%.1f" % [
					config_name, deck_id, level, RUNS, wins, float(wins) / float(RUNS),
					total_time / float(RUNS),
					float(lost_player) / float(RUNS),
					float(lost_enemy) / float(RUNS)
				])
		totals[config_name] = {
			"rate": float(config_wins) / float(config_games),
			"time": config_time / float(config_games)
		}
	print("summary")
	for config in CONFIGS:
		var config_label := String(config["name"])
		var stat: Dictionary = totals[config_label]
		print("%s,win_rate=%.2f,avg_seconds=%.1f" % [config_label, float(stat["rate"]), float(stat["time"])])
	battle.queue_free()
	quit()


func _shuffle_opening_hand(battle) -> void:
	var cards: Array = battle.player_hand.duplicate() + battle.player_draw_pile.duplicate()
	cards.shuffle()
	battle.player_hand = cards.slice(0, mini(5, cards.size()))
	battle.player_draw_pile = cards.slice(battle.player_hand.size())
	battle.selected_card_index = -1
	battle._refresh_hand()
