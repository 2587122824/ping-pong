extends SceneTree

# 临时校验：打开布阵原型时探索常驻 HUD 收起，关闭后恢复。

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: Variant = load("res://main.gd").new()
	root.add_child(game)
	await process_frame

	game._open_formation_battle()
	assert(game.formation_battle != null, "formation battle instantiated")
	assert(not game.player_status_hud.visible, "left status HUD hidden in formation")
	assert(not game.economy_hud.visible, "right menu HUD hidden in formation")
	assert(not game.interaction_hint.visible, "interaction hint hidden in formation")
	for child in game.get_children():
		if child is Node3D and child != game.formation_battle:
			assert(not child.visible, "world 3D node hidden in formation: " + child.name)

	game._close_formation_battle()
	assert(game.formation_battle == null, "formation freed on close")
	assert(game.player_status_hud.visible, "left status HUD restored")
	assert(game.economy_hud.visible, "right menu HUD restored")
	assert(game.interaction_hint.visible, "interaction hint restored")
	for child in game.get_children():
		if child is Node3D:
			assert(child.visible, "world 3D node restored: " + child.name)

	print("hud toggle ok")
	quit()
