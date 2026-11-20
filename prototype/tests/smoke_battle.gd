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

	assert(game.level_definitions.size() == 5, "The prototype should expose all five sample levels")
	game._open_level_select(challenger)
	assert(game.level_select_panel.visible, "Challenging the duelist should open level selection")
	assert(game.level_selected_id == "CH0-01", "The duel NPC should default to the tutorial level")
	assert(game.level_select_buttons.size() == 5, "Level selection should include teaching, normal, elite, boss, and side levels")
	game._close_level_select()
	game._start_battle(challenger, "CH1-01")
	assert(game.battle_panel.visible, "Starting a battle should show the battle panel")
	assert(game.battle_player_hp == 30, "The first battle should start at full health")
	assert(game.battle_opponent_hp == 55 and game.battle_opponent_max_hp == 55, "The normal sample should use its configured 55 health")
	assert(game.current_level_id == "CH1-01", "The battle should keep the selected level identity")
	assert(game.battle_hand.size() == 5, "A battle should start with five cards")
	assert(game.battle_card_widgets.size() == 5, "The battle should create five structured card faces")
	assert(game.battle_animation_layer != null, "The battle should create a card animation layer")
	assert(game.player_status_hud != null, "The player should have a screen status HUD")
	assert(game.player_status_hud.size == Vector2(300, 96), "The status HUD should use the compact two-row layout")
	assert(game.player_hp_bar.value == 30, "The HUD should display player health")
	assert(game.player_hp_value.text == "30 / 30", "The HUD should display the health value")
	assert(game.player_status_hud.get_children().filter(func(child: Node) -> bool: return child is ProgressBar).size() == 2, "The exploration HUD should only display health and experience bars")
	assert(game.battle_stamina_bar.value == game.PLAYER_MAX_STAMINA, "The battle HUD should display player stamina")
	assert(game.battle_intent.text.contains("快带") and game.battle_intent.text.contains("10"), "The battle HUD should display the selected level intent")
	assert(game.talent_button.text.begins_with("天赋"), "The progression entry should be labeled talent")
	assert(game._get_weapon_base_damage() == 4, "The default racket should provide four base damage")
	assert(game.equipment_slots["weapon"] == "starter_racket", "The default weapon slot should contain the starter racket")
	assert(game.equipment_slots["clothes"] == "" and game.equipment_slots["shoes"] == "" and game.equipment_slots["hat"] == "", "Non-weapon equipment slots should start empty")
	assert(game.equipment_summary.text.contains("4"), "The equipment panel summary should show the starter racket base damage")
	game.battle_hand.clear()
	game.battle_deck.clear()
	game.battle_discard.clear()
	game.battle_opponent_hp = 100
	for test_card in ["tt_tactic", "tt_control", "tt_main", "tt_sub", "tt_defense", "tt_resource"]:
		game.battle_hand.append({"id": test_card})

	game._play_battle_card(_find_card(game, "tt_tactic"))
	assert(game.player_stamina == 95, "Playing a tactic should spend its five stamina")
	assert(game.battle_next_action_damage_bonus == 3, "The tactic card should prepare a three damage bonus")
	game._play_battle_card(_find_card(game, "tt_control"))
	assert(game.battle_opponent_hp == 92, "Disrupt damage should include weapon base, move bonus, and tactic bonus")
	assert(game.battle_weakens_opponent, "The control move should weaken the opponent")
	game._play_battle_card(_find_card(game, "tt_main"))
	assert(game.battle_opponent_hp == 84, "A second action card should be playable when stamina permits")
	game._play_battle_card(_find_card(game, "tt_sub"))
	assert(game.battle_opponent_hp == 78, "The secondary move should deal four base plus two move damage")
	assert(game.player_stamina == 55, "Card costs should be deducted from the shared stamina budget")
	game._play_battle_card(_find_card(game, "tt_defense"))
	assert(game.battle_block == 7, "Guard should grant seven block")
	game._play_battle_card(_find_card(game, "tt_resource"))
	assert(game.battle_hand.size() <= 5, "Resource draw should respect the five-card hand limit")
	assert(game.player_stamina == 40, "Defense and resource costs should also use the shared stamina pool")

	game.battle_hand.clear()
	game.battle_hand.append({"id": "tt_main"})
	game.player_stamina = 0
	game._refresh_battle_ui()
	var unaffordable_index := _find_card(game, "tt_main")
	assert(game.battle_card_buttons[unaffordable_index].disabled, "Cards above current stamina should be disabled")
	game._play_battle_card(unaffordable_index)
	assert(game.battle_hand.size() == 1 and game.player_stamina == 0, "Insufficient stamina should be checked again when clicked")
	assert(game.battle_feedback_text.contains("体力不足"), "An unaffordable card should explain the stamina requirement")

	game.battle_hand.clear()
	game.battle_hand.append({"id": "tt_main"})
	game.battle_hand.append({"id": "tt_sub"})
	game.battle_discard.clear()
	for next_card in ["tt_main", "tt_sub", "tt_control", "tt_defense"]:
		game.battle_deck.append(next_card)
	game.battle_weakens_opponent = true
	game.battle_block = 7
	game.player_stamina = 10
	game._end_battle_turn()
	assert(game.battle_player_hp == 30, "Seven block should stop the weakened four damage attack")
	assert(game.player_hp_bar.value == 30, "The HUD should reflect health after turn resolution")
	assert(game.battle_turn == 2, "Ending a surviving turn should advance the turn")
	assert(game.battle_next_action_damage_bonus == 0, "Ending a turn should clear the tactic bonus")
	assert(game.player_stamina == 30, "The next player phase should restore twenty stamina")
	assert(game.battle_hand.size() == 5, "Ending a surviving turn should discard the full hand and draw five")

	game._start_battle(challenger)
	assert(game.player_stamina == 100, "Each new battle should reset stamina to full")
	game.battle_hand.clear()
	game.battle_deck.clear()
	game.battle_discard.clear()
	for recycled_card in ["tt_main", "tt_sub", "tt_defense", "tt_control", "tt_tactic"]:
		game.battle_discard.append(recycled_card)
	game._draw_battle_cards_to_five()
	assert(game.battle_shuffle_pending, "Recycling the discard pile should request a shuffle animation")
	assert(game.battle_pending_draw_indices.size() == 5, "Each recycled card should be queued for a draw animation")
	game._refresh_battle_ui()
	assert(not game.battle_shuffle_pending, "Refreshing the battle UI should launch and clear the shuffle animation request")
	assert(game.battle_pending_draw_indices.is_empty(), "Launching draw animations should clear the draw queue")

	game._close_battle()
	game._start_battle(challenger)
	assert(game.battle_player_hp == 30, "Starting another battle should preserve current health")
	game.battle_hand.clear()
	game.battle_hand.append({"id": "tt_sub"})
	game.battle_opponent_hp = 4
	game._play_battle_card(0)
	assert(game.battle_finished and game.battle_won, "Lethal damage should still resolve a victory")
	assert(game.player_xp == 10, "The tutorial clear should grant its configured ten experience")
	game._close_battle()
	game._start_battle(challenger)
	assert(game.battle_player_hp == 30, "Health should remain unchanged after victory and starting the next battle")
	assert(game.player_xp == 10, "Experience should persist between battles")
	assert(game.player_xp_bar.value == 10, "The experience HUD should display earned experience")

	game._start_battle(challenger, "CH0-B01")
	assert(game.battle_opponent_hp == 75 and game.battle_intent.text.contains("判定·警告"), "The boss should load its configured health and first intent")
	game.battle_player_hp = 1
	game._end_battle_turn()
	assert(game.battle_finished and game.battle_feedback_text.contains("重击 18 点"), "Defeat feedback should use the selected level's tactical advice")
	game.battle_player_hp = 30
	game._start_battle(challenger, "CH0-B01")
	game._end_battle_turn()
	assert(game.battle_player_hp == 20 and game.battle_intent.text.contains("蓄力") and game.battle_intent.text.contains("下一击 18"), "The boss charge should telegraph the next eighteen damage hit")
	game._end_battle_turn()
	assert(game.battle_player_hp == 20, "A charge intent should deal no damage")
	game._end_battle_turn()
	assert(game.battle_player_hp == 2, "The boss heavy attack should deal eighteen damage")

	game.battle_player_hp = 30
	game._start_battle(challenger, "CH1-E01")
	game._end_battle_turn()
	game.battle_block = 20
	game._end_battle_turn()
	assert(game.battle_player_hp == 8 and game.battle_feedback_text.contains("穿透格挡"), "The elite armor-break attack should bypass block")

	game.battle_player_hp = 30
	game._start_battle(challenger, "CH1-S01")
	game.battle_intent_index = 2
	game.player_stamina = 50
	game._refresh_battle_ui()
	assert(game.battle_intent.text.contains("下回合恢复 10"), "The side-level intent should warn about stamina suppression")
	game._end_battle_turn()
	assert(game.player_stamina == 60, "The side-level suppression should reduce this transition's stamina recovery to ten")

	game.player_xp = 0
	game.level_rewards_claimed.clear()
	game._start_battle(challenger, "CH1-S01")
	game._grant_battle_victory_xp()
	assert(game.player_xp == 40 and game.inventory["med_patch"] == 3, "First side-level clear should grant experience and two med patches")
	game.player_xp = 0
	game._grant_battle_victory_xp()
	assert(game.player_xp == 10 and game.inventory["med_patch"] == 3, "Repeat clear should grant only repeat experience")

	print("Battle smoke test passed")
	quit()

func _find_card(game: Variant, card_id: String) -> int:
	for index in range(game.battle_hand.size()):
		if game.battle_hand[index]["id"] == card_id:
			return index
	return -1
