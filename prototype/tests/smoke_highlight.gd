extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene = load("res://formation_battle_v03.tscn")
	var battle: Variant = scene.instantiate()
	root.add_child(battle)
	await process_frame

	assert(battle.hand.size() == 5, "hand dealt")
	battle._on_hand_pressed(0)
	assert(battle.selected_card == 0, "hand card 0 selected: %d" % battle.selected_card)

	var card_id := String(battle.hand[0])
	var fits_near: bool = battle.card_fits(card_id, 0)
	var fits_far: bool = battle.card_fits(card_id, 6)
	print("card=%s fits_near=%s fits_far=%s" % [card_id, fits_near, fits_far])

	# 高亮后：符合区域的空槽不应被压暗，不符合的槽 modulate 变暗
	var near_btn: Button = battle.slot_buttons["player"][0][battle.ROWS - 1 - 0]
	var far_btn: Button = battle.slot_buttons["player"][0][battle.ROWS - 1 - 6]
	if fits_near:
		assert(near_btn.modulate.get_luminance() > 0.8, "valid slot not dimmed")
	if not fits_far:
		assert(far_btn.modulate.get_luminance() < 0.8, "invalid slot dimmed")

	# 再点一次取消选中
	battle._on_hand_pressed(0)
	assert(battle.selected_card == -1, "second click deselects")

	# 引爆触发炸弹爆炸特效，位置归零
	battle.bombs[0]["pos"] = 2.0
	battle._detonate(0, "timer")
	assert(float(battle.bombs[0]["pos"]) == 0.0, "bomb resets after detonation")
	assert(battle.bomb_views[0].explosion > 0.0, "explosion effect triggered")
	print("highlight logic ok")
	quit()
