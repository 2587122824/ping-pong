extends SceneTree

# 输入链路探针：
# 1. 手牌内部任意子控件经过父链回溯都能识别到手牌下标（修复前会返回 -1）
# 2. 每个我方槽位：世界坐标 -> 视口局部 -> 屏幕坐标 -> _pick_slot 射线，命中槽位与原槽位一致
# 3. 合成鼠标点手牌根/子控件：按下后 drag_card 置位，抬起后进入选中态

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene = load("res://formation_battle_v03.tscn")
	var battle: Variant = scene.instantiate()
	root.add_child(battle)
	await process_frame
	await process_frame

	# --- 1. 手牌 meta 父链回溯 ---
	assert(battle.hand_buttons.size() == 5, "5 hand cards")
	for i in range(battle.hand_buttons.size()):
		var root_card: Control = battle.hand_buttons[i]
		var seen: Array[Control] = []
		_collect_controls(root_card, seen)
		assert(seen.size() > 1, "card %d has inner children" % i)
		for c in seen:
			var got: int = battle._hand_index_of(c)
			assert(got == i, "card %d child %s resolves hand_index=%d" % [i, c.get_class(), got])
		print("hand card %d meta walk ok (%d controls)" % [i, seen.size()])

	# --- 2. 槽位射线往返 ---
	var cam: Camera3D = battle.battle_camera
	var cont: SubViewportContainer = battle.board_container
	assert(cont != null and cont.size.x > 0, "board container laid out: %s" % str(cont.size))
	var vsize: Vector2 = Vector2(battle.board_viewport.size)
	var miss := 0
	for lane in range(3):
		for row in range(7):
			var wp: Vector3 = battle._slot_position("player", lane, row)
			var vl: Vector2 = cam.unproject_position(wp)
			var screen: Vector2 = cont.global_position + vl * cont.size / vsize
			var hit: Dictionary = battle._pick_slot(screen)
			var ok := not hit.is_empty() and String(hit["side"]) == "player" \
				and int(hit["lane"]) == lane and int(hit["row"]) == row
			if not ok:
				miss += 1
				print("MISS lane=%d row=%d wp=%s screen=%s hit=%s" % [lane, row, str(wp), str(screen), str(hit)])
	assert(miss == 0, "%d player slots missed" % miss)
	print("player slot ray round-trip ok (21)")

	# 真实鼠标悬停只能在有窗口环境下由视口算出；headless 下 gui_get_hovered_control 恒为空，
	# 父链回溯与射线往返已在上面两项覆盖，合成事件留待真实窗口复验。
	print("probe_input_v03 ok")
	quit()


func _collect_controls(n: Node, out: Array[Control]) -> void:
	for ch in n.get_children():
		if ch is Control:
			out.append(ch)
			_collect_controls(ch, out)
