extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Variant = load("res://main.gd").new()
	root.add_child(game)
	current_scene = game
	await process_frame

	var gate: Node3D = game.get_node("TransitGate")
	assert(gate != null, "Transit gate should be present")
	assert(gate.get_meta("target_scene") == "res://TransitRoom.tscn", "Gate should point to the transit scene")
	assert(game.player.global_position.distance_to(gate.get_meta("interaction_position")) < 3.2, "Main scene player should start beside the gate")

	game._update_nearby_npc()
	var interact := InputEventKey.new()
	interact.keycode = KEY_E
	interact.pressed = true
	game._unhandled_input(interact)
	await process_frame
	assert(current_scene != null and current_scene.name == "TransitRoom", "Entering the gate should change to the transit scene")
	var transit: Node = current_scene
	var return_gate: Node3D = transit.get_node("TransitGate")
	assert(return_gate != null, "Transit scene should also contain a return gate")
	assert(return_gate.get_meta("target_scene") == "res://Main.tscn", "Return gate should point to the original scene")
	assert(transit.player.global_position.distance_to(return_gate.get_meta("interaction_position")) < 3.2, "Transit scene player should start beside the return gate")
	transit._update_nearby_gate()
	transit._unhandled_input(interact)
	await process_frame
	assert(current_scene != null and current_scene.name == "Prototype", "Returning should load the original test area")

	print("Gate smoke test passed")
	quit()
