extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Variant = load("res://main.gd").new()
	root.add_child(game)
	await process_frame

	assert(game.talent_panel != null and game.talent_rows.get_child_count() == 4, "The talent panel should display all four prototype talents")
	assert(game.player_talent_points == 0, "The player should start without talent points")
	assert(not game._can_unlock_talent("tactical_memory"), "A talent with unmet prerequisites should not be unlockable")

	for _victory in range(4):
		game._grant_battle_victory_xp()
	assert(game.player_level == 2, "Four victories should reach the first level threshold")
	assert(game.player_talent_points == 1, "Leveling up should grant one talent point")
	assert(game._can_unlock_talent("racket_calibration"), "A root talent should be unlockable after leveling")
	game._unlock_talent("racket_calibration")
	assert(game._get_talent_bonus("action_damage_bonus") == 1, "Racket Calibration should add one action damage")
	assert(not game._can_unlock_talent("read_intent") or game.player_talent_points > 0, "Talent unlocks should respect available points")

	for _victory in range(16):
		game._grant_battle_victory_xp()
	assert(game.player_talent_points == 4, "Each additional level should grant one talent point")
	assert(game._can_unlock_talent("read_intent"), "The dependent skill should unlock after its prerequisite")
	game._unlock_talent("read_intent")
	game._unlock_talent("field_routine")
	game._unlock_talent("tactical_memory")
	assert(game.player_talent_points == 1, "Each unlocked talent should spend its configured point cost")
	assert(game._get_talent_bonus("start_block") == 2, "Intent Reading should grant two opening block")
	assert(game._get_talent_bonus("heal_bonus") == 2, "Field Routine should improve healing")
	assert(game._get_talent_bonus("tactic_bonus") == 1, "Tactical Memory should strengthen tactic cards")

	var challenger: Node3D
	for child in game.get_children():
		if child is CharacterBody3D and child.get_meta("npc_type", "") == "duelist":
			challenger = child
			break
	game._start_battle(challenger)
	assert(game.battle_block == 2, "Intent Reading should apply when a battle starts")
	game.battle_hand.clear()
	game.battle_hand.append({"id": "tt_tactic"})
	game.battle_hand.append({"id": "tt_main"})
	game._play_battle_card(0)
	assert(game.battle_next_action_damage_bonus == 4, "Tactical Memory should add one damage to Tactical Boost")
	assert(game.battle_feedback_text.contains("+4"), "Tactical Boost feedback should show the full skill-enhanced value")
	game._play_battle_card(0)
	assert(game.battle_opponent_hp == 17, "Racket Calibration and Tactical Memory should both affect attack damage")

	game._close_battle()
	game.battle_player_hp = 20
	game.inventory["energy_drink"] = 1
	game._use_item("energy_drink")
	assert(game.battle_player_hp == 28, "Field Routine should add two healing to the six-point energy drink")
	assert(game.inventory["energy_drink"] == 0, "Using a healing item should consume it")

	print("Talent smoke test passed")
	quit()
