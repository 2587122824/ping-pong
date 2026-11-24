extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Variant = load("res://main.gd").new()
	root.add_child(game)
	await process_frame

	assert(game.inventory_grid.columns == 3, "The inventory should use a three-column grid")
	assert(game.inventory_slots.size() == 9, "The inventory should contain nine slots")
	assert(game.inventory_slots[0].text.contains("能量饮料"), "The first slot should show the starting healing item")
	assert(game.inventory_slots[1].text.contains("急救贴"), "The second slot should show the starting med patch")

	game.battle_player_hp = 20
	game._use_item("energy_drink")
	assert(game.battle_player_hp == 38, "Energy drink should restore eighteen health")
	assert(game.inventory["energy_drink"] == 0, "Using a healing item should consume one")
	assert(game.inventory_slots[0].text == "空格", "An emptied stack should return its slot to empty")

	game.battle_player_hp = 75
	game._use_item("med_patch")
	assert(game.battle_player_hp == game.PLAYER_MAX_HP, "Healing should not exceed maximum health")
	assert(game.inventory["med_patch"] == 0, "A partially effective heal should still consume one item")
	game.inventory["med_patch"] = 1
	game._refresh_inventory_grid()
	game._use_item("med_patch")
	assert(game.inventory_feedback.text.contains("满"), "Full health should explain why healing is unavailable")
	assert(game.inventory["med_patch"] == 1, "Full health should not consume healing items")

	game.inventory["trauma_kit"] = 1
	game._refresh_inventory_grid()
	game.battle_player_hp = 10
	game._use_item("trauma_kit")
	assert(game.battle_player_hp == 64, "Trauma kit should restore fifty-four health")
	assert(game.inventory["trauma_kit"] == 0, "Using the trauma kit should consume it")

	game.inventory["data_chip"] = 1
	game._refresh_inventory_grid()
	game._use_item("data_chip")
	assert(game.inventory["data_chip"] == 1, "Non-consumable items should not be consumed")

	game._open_shop(_find_npc(game, "merchant"))
	var med_patch_count: int = game.inventory["med_patch"]
	game._buy_item("med_patch")
	assert(game.inventory["med_patch"] == med_patch_count + 1, "Buying a med patch should add it to the inventory")
	assert(game.inventory_slots[1].text.contains("×%d" % (med_patch_count + 1)), "The grid should refresh purchased stack counts")

	var challenger: Node3D = _find_npc(game, "duelist")
	game._close_shop()
	game._start_battle(challenger)
	game.battle_player_hp = 20
	game._use_item("med_patch")
	assert(game.battle_player_hp == 20, "Healing items should not work during battle")
	assert(game.inventory["med_patch"] == med_patch_count + 1, "Items should not be consumed when use is blocked in battle")

	print("Inventory smoke test passed")
	quit()

func _find_npc(game: Variant, npc_type: String) -> Node3D:
	for child in game.get_children():
		if child is CharacterBody3D and child.get_meta("npc_type", "") == npc_type:
			return child
	return null
