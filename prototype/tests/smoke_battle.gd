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
	assert(game.battle_player_hp == 30, "The first battle should start at full health")
	assert(game.battle_hand.size() == 5, "A battle should start with five cards")
	assert(game.battle_card_widgets.size() == 5, "The battle should create five structured card faces")
	assert(game.battle_animation_layer != null, "The battle should create a card animation layer")
	assert(game.player_status_hud != null, "The player should have a screen status HUD")
	assert(game.player_status_hud.size == Vector2(300, 122), "The status HUD should use the compact layout")
	assert(game.player_hp_bar.value == 30, "The HUD should display player health")
	assert(game.player_mana_bar.value == game.PLAYER_MAX_MANA, "The HUD should display player mana")
	assert(game.player_hp_value.text == "30 / 30", "The HUD should display the health value")
	assert(game.player_mana_value.text == "10 / 10", "The HUD should display the mana value")
	game.battle_hand.clear()
	for test_card in ["forehand", "backhand", "guard", "curve", "boost", "recycle"]:
		game.battle_hand.append({"id": test_card})

	var forehand_index := _find_card(game, "forehand")
	game._play_battle_card(forehand_index)
	assert(game.battle_opponent_hp == 24, "Forehand should deal six damage")
	assert(game.battle_category_uses["action"] == 1, "An action card should consume the shared action limit")
	assert(game.battle_hand.size() == 5, "A six-card test hand should return to five after one play")
	var second_damage_index := _find_card(game, "backhand")
	game._play_battle_card(second_damage_index)
	assert(game.battle_opponent_hp == 24, "A second action card should be blocked by the shared action limit")
	assert(_find_card(game, "backhand") >= 0, "A blocked card should remain in the hand")
	assert(game.battle_feedback_text.contains("行动牌"), "The blocked card should explain the category limit")

	var guard_index := _find_card(game, "guard")
	game._play_battle_card(guard_index)
	assert(game.battle_block == 7, "Guard should grant seven block")
	assert(game.battle_category_uses["defense"] == 1, "Guard should consume the defense limit")

	var boost_index := _find_card(game, "boost")
	game._play_battle_card(boost_index)
	assert(game.battle_category_uses["tactic"] == 1, "Boost should consume the tactic limit")
	assert(game.battle_next_action_damage_bonus == 3, "Boost should prepare a three damage bonus")

	game._end_battle_turn()
	assert(game.battle_player_hp == 29, "Seven block should reduce an eight damage attack to one")
	assert(game.player_hp_bar.value == 29, "The HUD should reflect damage after turn resolution")
	assert(game.battle_turn == 2, "Ending a surviving turn should advance the turn")
	assert(game.battle_category_uses.is_empty(), "Ending a surviving turn should reset category limits")
	assert(game.battle_next_action_damage_bonus == 0, "Ending a turn should clear the tactic bonus")
	assert(game.battle_hand.size() == 5, "Ending a surviving turn should refill the hand to five")

	game.battle_hand.clear()
	game.battle_category_uses.clear()
	game.battle_opponent_hp = 30
	for test_card in ["boost", "curve", "backhand", "recycle"]:
		game.battle_hand.append({"id": test_card})
	boost_index = _find_card(game, "boost")
	game._play_battle_card(boost_index)
	var curve_index := _find_card(game, "curve")
	game._play_battle_card(curve_index)
	assert(game.battle_opponent_hp == 24, "The tactic bonus should apply to a disrupt action")
	assert(game.battle_next_action_damage_bonus == 0, "The tactic bonus should be consumed by the next action")
	assert(game.battle_weakens_opponent, "Disrupt should weaken the opponent")

	var resource_index := _find_card(game, "recycle")
	var hand_before_resource: int = game.battle_hand.size()
	game._play_battle_card(resource_index)
	assert(game.battle_category_uses["resource"] == 1, "A resource card should consume the resource limit")
	assert(game.battle_hand.size() <= 5, "Resource draw should respect the five-card hand limit")
	assert(game.battle_hand.size() >= hand_before_resource - 1, "Resource play should not lose more cards than the played card")

	game.battle_card_definitions["focus"] = {"name": "专注", "type": "focus", "effect": "none", "value": 0, "description": "测试新增牌类"}
	game.battle_hand.append({"id": "focus"})
	var focus_index := _find_card(game, "focus")
	game._play_battle_card(focus_index)
	assert(game.battle_category_uses["focus"] == 1, "A newly added card type should automatically receive a category limit")
	game.battle_hand.append({"id": "focus"})
	focus_index = _find_card(game, "focus")
	game._play_battle_card(focus_index)
	assert(_find_card(game, "focus") >= 0, "The second card of a new category should remain in hand")

	game._start_battle(challenger)
	game.battle_hand.clear()
	game.battle_deck.clear()
	game.battle_discard.clear()
	for recycled_card in ["forehand", "backhand", "guard", "curve", "boost"]:
		game.battle_discard.append(recycled_card)
	game._draw_battle_cards_to_five()
	assert(game.battle_shuffle_pending, "Recycling the discard pile should request a shuffle animation")
	assert(game.battle_pending_draw_indices.size() == 5, "Each recycled card should be queued for a draw animation")
	game._refresh_battle_ui()
	assert(not game.battle_shuffle_pending, "Refreshing the battle UI should launch and clear the shuffle animation request")
	assert(game.battle_pending_draw_indices.is_empty(), "Launching draw animations should clear the draw queue")

	game._close_battle()
	game._start_battle(challenger)
	assert(game.battle_player_hp == 29, "Starting another battle should preserve lost health")
	game.battle_hand.clear()
	game.battle_hand.append({"id": "backhand"})
	game.battle_opponent_hp = 4
	game._play_battle_card(0)
	assert(game.battle_finished and game.battle_won, "Lethal damage should still resolve a victory")
	assert(game.player_xp == 25, "A victory should grant experience")
	game._close_battle()
	game._start_battle(challenger)
	assert(game.battle_player_hp == 29, "Health should remain unchanged after victory and starting the next battle")
	assert(game.player_xp == 25, "Experience should persist between battles")
	assert(game.player_xp_bar.value == 25, "The experience HUD should display earned experience")

	print("Battle smoke test passed")
	quit()

func _find_card(game: Variant, card_id: String) -> int:
	for index in range(game.battle_hand.size()):
		if game.battle_hand[index]["id"] == card_id:
			return index
	return -1
