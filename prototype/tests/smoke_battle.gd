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
	assert(game.battle_card_widgets.size() == 5, "The battle should create five structured card faces")
	assert(game.battle_animation_layer != null, "The battle should create a card animation layer")

	var forehand_index := _find_card(game, "forehand")
	assert(forehand_index >= 0, "The opening hand should contain a forehand card")
	game._play_battle_card(forehand_index)
	assert(game.battle_opponent_hp == 24, "Forehand should deal six damage")
	assert(game.battle_type_uses["damage"] == 1, "Playing a damage card should consume the damage type limit")
	assert(game.battle_hand.size() == 4, "Playing a card should not immediately draw a replacement")
	var second_damage_index := _find_card(game, "backhand")
	assert(second_damage_index >= 0, "The opening hand should contain a second damage card")
	game._play_battle_card(second_damage_index)
	assert(game.battle_opponent_hp == 24, "A second damage card should be blocked by the per-type limit")
	assert(game.battle_hand.size() == 4, "A blocked card should remain in the hand")
	assert(game.battle_feedback_text.contains("每回合最多使用 1 张"), "The blocked card should explain the type limit")

	var guard_index := _find_card(game, "guard")
	assert(guard_index >= 0, "The opening hand should contain a guard card")
	game._play_battle_card(guard_index)
	assert(game.battle_block == 7, "Guard should grant seven block")
	game.battle_card_definitions["focus"] = {"name": "专注", "type": "focus", "value": 0, "description": "测试新增牌类"}
	game.battle_hand.append({"id": "focus"})
	var focus_index := _find_card(game, "focus")
	game._play_battle_card(focus_index)
	assert(game.battle_type_uses["focus"] == 1, "A newly added card type should automatically receive a type limit")
	game.battle_hand.append({"id": "focus"})
	focus_index = _find_card(game, "focus")
	game._play_battle_card(focus_index)
	assert(game.battle_hand.size() == 4, "The second card of a newly added type should remain in hand")
	game._end_battle_turn()
	assert(game.battle_player_hp == 29, "Seven block should reduce an eight damage attack to one")
	assert(game.battle_turn == 2, "Ending a surviving turn should advance the turn")
	assert(game.battle_type_uses.is_empty(), "Ending a surviving turn should reset all type limits")
	assert(game.battle_hand.size() == 5, "Ending a surviving turn should refill the hand to five")

	game.battle_opponent_hp = 4
	var damage_index := _find_card(game, "backhand")
	if damage_index < 0:
		damage_index = _find_card(game, "forehand")
	assert(damage_index >= 0, "A damage card should be available for the victory check")
	game._play_battle_card(damage_index)
	assert(game.battle_finished, "Reducing the opponent to zero should finish the battle")
	assert(game.battle_won, "Reducing the opponent to zero should mark a victory")

	game._start_battle(challenger)
	game.battle_hand.clear()
	game.battle_deck.clear()
	game.battle_discard.clear()
	for recycled_card in ["forehand", "backhand", "guard", "curve", "forehand"]:
		game.battle_discard.append(recycled_card)
	game._draw_battle_cards_to_five()
	assert(game.battle_shuffle_pending, "Recycling the discard pile should request a shuffle animation")
	assert(game.battle_pending_draw_indices.size() == 5, "Each recycled card should be queued for a draw animation")
	game._refresh_battle_ui()
	assert(not game.battle_shuffle_pending, "Refreshing the battle UI should launch and clear the shuffle animation request")
	assert(game.battle_pending_draw_indices.is_empty(), "Launching draw animations should clear the draw queue")

	print("Battle smoke test passed")
	quit()

func _find_card(game: Variant, card_id: String) -> int:
	for index in range(game.battle_hand.size()):
		if game.battle_hand[index]["id"] == card_id:
			return index
	return -1
