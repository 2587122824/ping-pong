extends SceneTree

# 新手教学引导探针：自动弹出、分步翻页、锚点高亮、上一步/完成/跳过关闭均可走通。

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene = load("res://formation_battle_v03.tscn")
	var battle: Variant = scene.instantiate()
	root.add_child(battle)
	await process_frame
	await process_frame

	# 首次进入自动弹出
	assert(battle.tutorial_open == true, "tutorial auto opened")
	assert(battle.tutorial_panel.visible, "panel visible")
	assert(battle.tutorial_steps.size() == 7, "steps count: %d" % battle.tutorial_steps.size())
	assert(battle.tutorial_step_label.text == "1 / 7", "step label: %s" % battle.tutorial_step_label.text)
	assert(battle.tutorial_prev.disabled, "prev disabled on first")
	assert(not battle.tutorial_title.text.is_empty(), "title set")
	assert(not battle.tutorial_body.text.is_empty(), "body set")

	# 一路翻到最后一步
	var last: int = battle.tutorial_steps.size() - 1
	for i in range(last):
		battle._tutorial_next()
		await process_frame
		assert(battle.tutorial_step == i + 1, "step advanced: %d" % battle.tutorial_step)
		assert(battle.tutorial_hl.visible, "highlight visible at step %d" % battle.tutorial_step)
		assert(battle.tutorial_next.text == ("完成" if i + 1 == last else "下一步"), "next button label")

	# 最后一步点完成 -> 关闭
	battle._tutorial_next()
	await process_frame
	assert(battle.tutorial_open == false, "tutorial closed after finish")
	assert(not battle.tutorial_panel.visible, "panel hidden")

	# 上一步回退不越界
	battle.open_tutorial()
	await process_frame
	battle._tutorial_next()
	await process_frame
	battle._tutorial_prev()
	await process_frame
	assert(battle.tutorial_step == 0, "back to first: %d" % battle.tutorial_step)

	# 跳过按钮关闭
	battle.close_tutorial()
	await process_frame
	assert(not battle.tutorial_panel.visible, "panel hidden after skip")

	print("tutorial probe ok: steps=%d" % battle.tutorial_steps.size())
	battle.queue_free()
	quit()
