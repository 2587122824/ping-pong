extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Variant = load("res://main.gd").new()
	root.add_child(game)
	await process_frame

	var merchant: Node3D
	for child in game.get_children():
		if child is CharacterBody3D and child.get_meta("npc_type", "") == "merchant":
			merchant = child
			break
	assert(merchant != null, "Merchant NPC should be present")

	game._open_shop(merchant)
	var initial_money: int = game.money
	var initial_count: int = game.inventory["energy_drink"]
	game._buy_item("energy_drink")
	assert(game.money == initial_money - 20, "Buying should deduct the listed price")
	assert(game.inventory["energy_drink"] == initial_count + 1, "Buying should add one item")

	game._sell_item("energy_drink")
	assert(game.money == initial_money - 10, "Selling should add the listed resale price")
	assert(game.inventory["energy_drink"] == initial_count, "Selling should remove one item")

	game.money = 0
	var chip_count: int = game.inventory["data_chip"]
	game._buy_item("data_chip")
	assert(game.money == 0, "A failed purchase must not change money")
	assert(game.inventory["data_chip"] == chip_count, "A failed purchase must not add an item")
	assert(game.shop_feedback.text.contains("不足"), "The player should see why the purchase failed")

	print("Trade smoke test passed")
	quit()
