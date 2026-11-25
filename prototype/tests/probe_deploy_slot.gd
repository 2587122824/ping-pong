extends SceneTree

# 走与鼠标射线命中后完全相同的入口 _on_slot：选牌 -> 找符合区域的槽位 -> 部署 -> 断言棋子落盘

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://formation_battle_v03.tscn")
	var battle: Variant = scene.instantiate()
	root.add_child(battle)
	await process_frame
	await process_frame

	battle._on_hand_pressed(0)
	assert(battle.selected_card == 0, "card 0 selected")
	var card_id := String(battle.hand[0])
	print("card0=%s zone=%s" % [card_id, str(battle.CARDS[card_id]["zone"])])

	var placed := false
	for lane in range(3):
		for row in range(7):
			if battle.board["player"][lane][row] != null:
				continue
			if battle.card_fits(card_id, row):
				battle._on_slot("player", lane, row)
				assert(battle.board["player"][lane][row] != null, "unit deployed at lane=%d row=%d" % [lane, row])
				placed = true
				print("deployed lane=%d row=%d" % [lane, row])
				break
		if placed:
			break
	assert(placed, "found a fitting empty slot")
	assert(battle.selected_card == -1, "selection cleared after deploy")
	assert(battle.hand.size() == 5, "hand refilled: %d" % battle.hand.size())
	print("on_slot deploy ok")
	quit()
