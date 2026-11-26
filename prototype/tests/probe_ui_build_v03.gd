extends SceneTree

# 完整 UI 构建探针：实机路径下 _build_world/_build_ui 不报错，
# 连携光弧导轨生成、尾焰 puff 入列、合成音效节点创建均可用。

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene = load("res://formation_battle_v03.tscn")
	var battle: Variant = scene.instantiate()
	battle.show_tutorial_on_ready = false
	root.add_child(battle)
	await process_frame
	await process_frame

	assert(battle.board_viewport != null, "3D viewport built")
	battle.level_id = "CH0-B01"
	battle.restart()

	# 同路摆短(控台) + 前冲弧圈(重击) -> 调动起板光弧
	battle._spawn("tt_short", "player", 1, 0, false)
	battle._spawn("tt_loop", "player", 1, 2, false)
	# 同路正手快攻 + 反手快攻 -> 双拍连击光弧
	battle._spawn("tt_main", "player", 2, 0, false)
	battle._spawn("tt_rip", "player", 2, 1, false)
	battle._refresh()
	await process_frame

	assert(battle.combo_lines.size() >= 2, "combo rails created: %d" % battle.combo_lines.size())
	for line in battle.combo_lines:
		assert(line != null and is_instance_valid(line), "rail valid")

	battle.start_battle()
	for i in range(12):
		battle.tick(0.1)
		await process_frame

	assert(battle.trail_puffs.size() > 0, "trail puffs spawned: %d" % battle.trail_puffs.size())
	assert(battle.sfx_players.size() > 0, "sfx players created: %d" % battle.sfx_players.size())

	# 击溃敌方 -> 胜利音效入列
	battle._damage_side("enemy", 999, "probe")
	await process_frame
	assert(battle.phase == "won", "battle won")
	assert(battle.sfx_players.has("win"), "win sfx created")
	assert(battle.sfx_cache.has("win"), "win stream cached")

	print("ui build probe ok: rails=%d puffs=%d sfx=%d" % [battle.combo_lines.size(), battle.trail_puffs.size(), battle.sfx_players.size()])
	battle.queue_free()
	quit()
