extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Variant = load("res://main.gd").new()
	root.add_child(game)
	await process_frame

	var challenger: Node3D
	for child in game.get_children():
		if child is CharacterBody3D and child.get_meta("npc_type", "") == "duelist":
			challenger = child
			break
	assert(challenger != null, "Duelist NPC should be present")

	game._start_battle(challenger)
	assert(game.battle_panel.visible, "Starting a battle should show the battle panel")
	assert(game.battle_hand.size() == 5, "A battle should start with five cards")

	var forehand_index := _find_card(game, "forehand")
	assert(forehand_index >= 0, "The opening hand should contain a forehand card")
	game._play_battle_card(forehand_index)
	assert(game.battle_opponent_hp == 24, "Forehand should deal six damage")
	assert(game.battle_energy == 2, "Forehand should cost one energy")
	assert(game.battle_hand.size() == 4, "Playing a card should not immediately draw a replacement")

	var guard_index := _find_card(game, "guard")
	assert(guard_index >= 0, "The opening hand should contain a guard card")
	game._play_battle_card(guard_index)
	assert(game.battle_block == 7, "Guard should grant seven block")
	game._end_battle_turn()
	assert(game.battle_player_hp == 29, "Seven block should reduce an eight damage attack to one")
	assert(game.battle_turn == 2, "Ending a surviving turn should advance the turn")
	assert(game.battle_energy == 3, "A new turn should restore three energy")
	assert(game.battle_hand.size() == 5, "Ending a surviving turn should refill the hand to five")

	game.battle_opponent_hp = 4
	var damage_index := _find_card(game, "backhand")
	if damage_index < 0:
		damage_index = _find_card(game, "forehand")
	assert(damage_index >= 0, "A damage card should be available for the victory check")
	game._play_battle_card(damage_index)
	assert(game.battle_finished, "Reducing the opponent to zero should finish the battle")
	assert(game.battle_won, "Reducing the opponent to zero should mark a victory")

	print("Battle smoke test passed")
	quit()

func _find_card(game: Variant, card_id: String) -> int:
	for index in range(game.battle_hand.size()):
		if game.battle_hand[index]["id"] == card_id:
			return index
	return -1
