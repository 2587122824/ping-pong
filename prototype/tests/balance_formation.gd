extends SceneTree

# 平衡基线模拟：三阵营 × 五关卡 × 三种打法 × 多次对局。
# 玩家侧使用原型自带的一键布阵与贪心补位，只用于观察数值区间与阵营差异，不代表真人胜率。
# 运行：
# & $env:LOCALAPPDATA\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path prototype --script res://tests/balance_formation.gd

const DECKS := ["vanguard", "aero", "bastion"]
const LEVELS := ["CH0-01", "CH1-01", "CH1-E01", "CH0-B01", "CH1-S01"]
const LEVEL_BUDGET := {
	"CH0-01": 15,
	"CH1-01": 35,
	"CH1-E01": 55,
	"CH0-B01": 75,
	"CH1-S01": 55
}
const MODES := ["full_auto", "opening_only", "enemy_budget", "both", "paced_both", "paced3_both"]
const RUNS := 6
const MAX_SIM_SECONDS := 120.0
const STEP := 0.1


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

	print("mode,deck,level,runs,wins,win_rate,avg_seconds,avg_player_left,avg_enemy_left,avg_lost_player,avg_lost_enemy,sudden_death")
	for mode in MODES:
		for deck_index in range(DECKS.size()):
			var deck_id: String = DECKS[deck_index]
			for level_index in range(LEVELS.size()):
				var level: String = LEVELS[level_index]
				var wins := 0
				var total_time := 0.0
				var left_player := 0
				var left_enemy := 0
				var lost_player := 0
				var lost_enemy := 0
				var sudden := 0
				for run_index in range(RUNS):
					seed(900000 + deck_index * 1000 + level_index * 40 + run_index)
					battle.player_deck_id = deck_id
					battle.level_id = level
					battle.restart_battle()
					_shuffle_opening_hand(battle)
					battle.auto_deploy_formation()
					battle.start_battle()
					if mode == "enemy_budget" or mode == "both" or mode == "paced_both" or mode == "paced3_both":
						battle.enemy_stamina = int(LEVEL_BUDGET[level])
					var reinforce_gap := 5
					if mode == "paced_both":
						reinforce_gap = 50
					elif mode == "paced3_both":
						reinforce_gap = 30
					var steps := 0
					while String(battle.phase) == "battle" and steps < int(MAX_SIM_SECONDS / STEP):
						battle.tick(STEP)
						if (mode == "full_auto" or mode == "both" or mode == "paced_both" or mode == "paced3_both") and steps % reinforce_gap == 0:
							battle.auto_reinforce_battle()
						steps += 1
					if String(battle.phase) == "won":
						wins += 1
					if battle.sudden_death_active:
						sudden += 1
					total_time += battle.battle_time
					left_player += battle._count_side_units("player")
					left_enemy += battle._count_side_units("enemy")
					lost_player += int(battle.units_lost["player"])
					lost_enemy += int(battle.units_lost["enemy"])
				print("%s,%s,%s,%d,%d,%.2f,%.1f,%.1f,%.1f,%.1f,%.1f,%d" % [
					mode, deck_id, level, RUNS, wins, float(wins) / float(RUNS),
					total_time / float(RUNS),
					float(left_player) / float(RUNS),
					float(left_enemy) / float(RUNS),
					float(lost_player) / float(RUNS),
					float(lost_enemy) / float(RUNS),
					sudden
				])
	print("balance run done")
	battle.queue_free()
	quit()


func _shuffle_opening_hand(battle) -> void:
	var cards: Array = battle.player_hand.duplicate() + battle.player_draw_pile.duplicate()
	cards.shuffle()
	battle.player_hand = cards.slice(0, mini(5, cards.size()))
	battle.player_draw_pile = cards.slice(battle.player_hand.size())
	battle.selected_card_index = -1
	battle._refresh_hand()
