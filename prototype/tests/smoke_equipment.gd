extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Variant = load("res://main.gd").new()
	root.add_child(game)
	await process_frame

	assert(game.equipment_slots.size() == 4, "The equipment module should expose four equipment slots")
	for slot_id in ["weapon", "clothes", "shoes", "hat"]:
		assert(game.EQUIPMENT_SLOT_NAMES.has(slot_id), "The equipment slot should have a localized label")
	assert(game.equipment_slots["weapon"] == "starter_racket", "The player should start with a racket")
	assert(game._get_weapon_attack() == 2, "The starter racket should provide two attack")
	assert(game.equipment_slots["clothes"].is_empty(), "Clothes should start empty")
	assert(game.equipment_slots["shoes"].is_empty(), "Shoes should start empty")
	assert(game.equipment_slots["hat"].is_empty(), "Hat should start empty")
	assert(game.equipment_slot_widgets.size() == 4, "The equipment panel should render all four slots")
	assert(game.equipment_slot_widgets["weapon"].text.contains("训练球拍"), "The weapon slot should show the starter racket")
	assert(game.equipment_slot_widgets["weapon"].text.contains("+2"), "The weapon slot should show its attack value")
	assert(game.equipment_slot_widgets["clothes"].text == "未装备", "Empty slots should show an unequipped state")

	game.battle_panel.visible = true
	game.battle_hand.clear()
	game.battle_hand.append({"id": "guard"})
	game._play_battle_card(0)
	assert(game.battle_block == 7, "Defense cards should not gain weapon attack")

	print("Equipment smoke test passed")
	quit()
