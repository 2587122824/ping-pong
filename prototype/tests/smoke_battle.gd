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

	# 关卡与牌组结构
	assert(game.level_definitions.size() == 5, "Five sample levels should be exposed")
	game._open_level_select(challenger)
	assert(game.level_select_panel.visible, "Challenging the duelist should open level selection")
	assert(game.level_selected_id == "CH0-01", "The duel NPC should default to the tutorial level")
	assert(game.level_select_buttons.size() == 5, "Level selection should list every level")
	game._close_level_select()
	assert(game.battle_decks.size() == 1, "Only the table tennis deck should remain")
	assert(game.player_deck.size() == 13, "The table tennis deck should hold thirteen cards")

	game._start_battle(challenger, "CH1-01")
	assert(game.battle_panel.visible, "Starting a battle should show the battle panel")
	assert(game.battle_player_hp == 100, "The player should start at one hundred health")
	assert(game.battle_opponent_hp == 140 and game.battle_opponent_max_hp == 140, "The normal level should use its configured one hundred forty health")
	assert(game.current_level_id == "CH1-01", "The battle should keep the selected level identity")
	assert(game.battle_hand.size() == 5, "A battle should start with five cards")
	assert(game.battle_card_widgets.size() == 5, "The battle should create five structured card faces")
	assert(game._get_weapon_base_damage() == 8, "The wooden stick should provide eight base damage")
	assert(game.equipment_slots["weapon"] == "starter_racket", "The default weapon slot should hold the starter weapon")
	assert(String(game.equipment_definitions["starter_racket"]["name"]) == "木棍", "The starter weapon should be a wooden stick")
	assert(game.player_hp_value.text == "100 / 100", "The HUD should display one hundred health")
	assert(game.battle_intent.text.contains("快带") and game.battle_intent.text.contains("16"), "The battle HUD should display the level intent")

	# 出牌：霸王拧 → 正手快攻 → 正手快带 → 反手快攻（抽 1）
	game.battle_hand.clear()
	game.battle_deck.clear()
	game.battle_discard.clear()
	for test_card in ["tt_tactic", "tt_main", "tt_sub", "tt_rip", "tt_defense"]:
		game.battle_hand.append({"id": test_card})
	game.battle_opponent_hp = 140
	game.player_stamina = 100

	game._play_battle_card(_find_card(game, "tt_tactic"))
	assert(game.player_stamina == 50, "霸王拧 should cost fifty stamina")
	assert(game.battle_next_action_damage_bonus == 20, "霸王拧 should prepare a twenty damage bonus")
	game._play_battle_card(_find_card(game, "tt_main"))
	assert(game.battle_opponent_hp == 96, "正手快攻 should deal eight base plus sixteen move plus twenty tactic")
	assert(game.player_stamina == 30, "正手快攻 should cost twenty stamina")
	game._play_battle_card(_find_card(game, "tt_sub"))
	assert(game.battle_opponent_hp == 81, "正手快带 should deal fifteen damage")
	assert(game.player_stamina == 20, "正手快带 should cost ten stamina")
	game._play_battle_card(_find_card(game, "tt_rip"))
	assert(game.battle_opponent_hp == 59, "反手快攻 should deal twenty-two damage")
	assert(game.battle_hand.size() == 2, "反手快攻 should draw one card back into the hand")
	assert(game.player_stamina == 0, "反手快攻 should cost twenty stamina")

	game.battle_hand.clear()
	game.battle_hand.append({"id": "tt_main"})
	game._refresh_battle_ui()
	var unaffordable_index := _find_card(game, "tt_main")
	assert(game.battle_card_buttons[unaffordable_index].disabled, "Cards above current stamina should be disabled")
	game._play_battle_card(unaffordable_index)
	assert(game.battle_hand.size() == 1 and game.player_stamina == 0, "Insufficient stamina should be checked again when clicked")
	assert(game.battle_feedback_text.contains("体力不足"), "An unaffordable card should explain the stamina requirement")

	# 反拉：完全挡下则反击
	game._start_battle(challenger, "CH0-01")
	game.battle_player_hp = 100
	game.battle_hand.clear()
	game.battle_hand.append({"id": "tt_defense"})
	game.player_stamina = 100
	game._play_battle_card(0)
	assert(game.battle_block == 14, "正手反拉 should grant fourteen block")
	assert(game.battle_counter_damage == 18, "正手反拉 should arm an eighteen damage counter")
	game._end_battle_turn()
	assert(game.battle_player_hp == 100, "Fourteen block should fully stop the tutorial ten damage serve")
	assert(game.battle_opponent_hp == 62, "A fully blocked attack should trigger the eighteen damage counter")
	assert(game.battle_feedback_text.contains("反击"), "Counter feedback should mention the counterattack")

	# 加转弧圈球：敌方本回合攻击下降
	game._start_battle(challenger, "CH0-01")
	game.battle_player_hp = 100
	game.battle_hand.clear()
	game.battle_hand.append({"id": "tt_spin"})
	game.player_stamina = 100
	game._play_battle_card(0)
	assert(game.battle_opponent_hp == 52, "加转弧圈球 should deal twenty-eight damage")
	assert(game.battle_enemy_slow == 6, "加转弧圈球 should slow the incoming attack by six")
	game._end_battle_turn()
	assert(game.battle_player_hp == 96, "The slowed tutorial serve should deal only four damage")

	# 转不转发球：下一张 +6，且本回合敌方攻击减半
	game._start_battle(challenger, "CH0-01")
	game.battle_player_hp = 100
	game.battle_hand.clear()
	game.battle_hand.append({"id": "tt_serve"})
	game.battle_hand.append({"id": "tt_main"})
	game.player_stamina = 100
	game._play_battle_card(0)
	assert(game.battle_next_action_damage_bonus == 6, "转不转发球 should add six to the next action")
	assert(game.battle_weakens_opponent, "转不转发球 should weaken the incoming attack")
	game._play_battle_card(0)
	assert(game.battle_opponent_hp == 50, "The boosted 正手快攻 should deal thirty damage")
	game._end_battle_turn()
	assert(game.battle_player_hp == 95, "The weakened tutorial serve should deal five damage")

	# 破防：无视格挡
	game._start_battle(challenger, "CH1-E01")
	game.battle_player_hp = 100
	game.battle_intent_index = 1
	game.battle_block = 20
	game._end_battle_turn()
	assert(game.battle_player_hp == 74 and game.battle_feedback_text.contains("穿透格挡"), "The elite armor-break attack should bypass block")

	# 小孩哥：抢点 → 假动作 → 扑杀
	game._start_battle(challenger, "CH0-B01")
	game.battle_player_hp = 100
	assert(game.battle_opponent_max_hp == 150 and game.battle_intent.text.contains("快攻抢点"), "小孩哥 should load its configured health and first intent")
	game._end_battle_turn()
	assert(game.battle_player_hp == 84, "The boss opening should deal sixteen damage")
	assert(game.battle_intent.text.contains("假动作") and game.battle_intent.text.contains("下一击 30"), "The feint should telegraph the next thirty damage hit")
	game._end_battle_turn()
	assert(game.battle_player_hp == 84, "The feint should deal no damage")
	game._end_battle_turn()
	assert(game.battle_player_hp == 54, "The boss smash should deal thirty damage")

	# 小区大爷：搓短压制恢复 → 长胶穿防 → 磨体力
	game._start_battle(challenger, "CH0-B02")
	game.battle_player_hp = 100
	assert(game.battle_opponent_max_hp == 200 and game.battle_intent.text.contains("搓短"), "小区大爷 should load its configured health and first intent")
	game.player_stamina = 50
	game._end_battle_turn()
	assert(game.battle_player_hp == 88, "The uncle chop should deal twelve damage")
	assert(game.player_stamina == 60, "Suppressed recovery should only restore ten stamina")
	game.battle_block = 20
	game._end_battle_turn()
	assert(game.battle_player_hp == 66 and game.battle_feedback_text.contains("穿透格挡"), "The long-pip attack should ignore block")
	game.player_stamina = 50
	game._end_battle_turn()
	assert(game.player_stamina == 55, "The grinding intent should cap recovery at five")

	# 经验与生命保持
	game._close_battle()
	game.battle_player_hp = 70
	game._start_battle(challenger, "CH0-01")
	assert(game.battle_player_hp == 70, "Starting another battle should preserve current health")
	game.battle_hand.clear()
	game.battle_discard.clear()
	game.battle_deck.clear()
	game.battle_hand.append({"id": "tt_sub"})
	game.battle_opponent_hp = 10
	game.player_stamina = 100
	game._play_battle_card(0)
	assert(game.battle_finished and game.battle_won, "Lethal damage should still resolve a victory")
	assert(game.player_xp == 10, "The tutorial clear should grant its configured ten experience")

	print("Battle smoke test passed")
	quit()

func _find_card(game: Variant, card_id: String) -> int:
	for index in range(game.battle_hand.size()):
		if game.battle_hand[index]["id"] == card_id:
			return index
	return -1
