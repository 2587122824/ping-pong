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
	assert(game.gate_panel != null and not game.gate_panel.visible, "Gate panel should start hidden")

	game._open_gate_panel()
	assert(game.gate_panel.visible, "Opening the gate should show the confirmation panel")
	game._close_gate_panel()
	assert(not game.gate_panel.visible, "Closing the gate should hide the confirmation panel")

	game._enter_gate()
	await process_frame
	assert(current_scene != null and current_scene.name == "TransitRoom", "Entering the gate should change to the transit scene")
	var transit: Node = current_scene
	var return_gate: Node3D = transit.get_node("TransitGate")
	assert(return_gate != null, "Transit scene should also contain a return gate")
	assert(return_gate.get_meta("target_scene") == "res://Main.tscn", "Return gate should point to the original scene")
	assert(transit.gate_panel != null and not transit.gate_panel.visible, "Return gate panel should start hidden")
	transit._open_gate_panel()
	assert(transit.gate_panel.visible, "Return gate should open the confirmation panel")
	transit._enter_gate()
	await process_frame
	assert(current_scene != null and current_scene.name == "Prototype", "Returning should load the original test area")

	print("Gate smoke test passed")
	quit()
