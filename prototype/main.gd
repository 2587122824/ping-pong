extends Node3D

const PLAYER_SPEED := 5.0
const INTERACTION_DISTANCE := 3.2

var player: CharacterBody3D
var camera: Camera3D
var nearby_npc: Node3D
var dialogue_panel: Panel
var dialogue_title: Label
var dialogue_text: Label
var interaction_hint: Label
var dialogue_index := 0
var dialogue_lines: Array[String] = []

var npcs := [
	{
		"name": "林遥",
		"role": "城市接口工程师",
		"position": Vector3(3.5, 1.0, -3.0),
		"color": Color("#4cc9f0"),
		"lines": [
			"你也是第一次来这片测试区？",
			"这里的公共现实层还没有完全同步，看到不同的东西很正常。",
			"先和另一位访客聊聊，也许她知道入口在哪里。"
		]
	},
	{
		"name": "周岚",
		"role": "独立记录员",
		"position": Vector3(-3.5, 1.0, -5.0),
		"color": Color("#f72585"),
		"lines": [
			"我在记录这里的居民如何使用自己的现实层。",
			"林遥说的入口，可能只对拥有工程权限的人开放。",
			"如果你愿意帮忙，我可以把这段记录交给你。"
		]
	}
]

func _ready() -> void:
	_setup_world()
	_setup_player()
	_setup_npcs()
	_setup_ui()

func _physics_process(delta: float) -> void:
	_move_player(delta)
	_update_camera()
	_update_nearby_npc()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E and nearby_npc != null:
			_open_or_advance_dialogue(nearby_npc)
		elif event.keycode == KEY_ESCAPE:
			_close_dialogue()

func _setup_world() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#08111f")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8db4d9")
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	add_child(environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_color = Color("#b9d7ff")
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)

	var ground := StaticBody3D.new()
	ground.name = "Ground"
	var ground_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(24, 24)
	ground_mesh.mesh = plane
	ground_mesh.material_override = _material(Color("#17283b"))
	ground.add_child(ground_mesh)
	var ground_collision := CollisionShape3D.new()
	var ground_shape := BoxShape3D.new()
	ground_shape.size = Vector3(24, 0.2, 24)
	ground_collision.shape = ground_shape
	ground_collision.position.y = -0.1
	ground.add_child(ground_collision)
	add_child(ground)

	for marker in [Vector3(0, 0.03, 0), Vector3(0, 0.03, -4), Vector3(4, 0.03, -4)]:
		var ring := MeshInstance3D.new()
		var ring_mesh := CylinderMesh.new()
		ring_mesh.top_radius = 1.35
		ring_mesh.bottom_radius = 1.35
		ring_mesh.height = 0.03
		ring.mesh = ring_mesh
		ring.position = marker
		ring.material_override = _material(Color("#213f5a"))
		add_child(ring)

	for x in [-8.0, 8.0]:
		var pillar := MeshInstance3D.new()
		var pillar_mesh := BoxMesh.new()
		pillar_mesh.size = Vector3(0.25, 4.0, 0.25)
		pillar.mesh = pillar_mesh
		pillar.position = Vector3(x, 2.0, -8.0)
		pillar.material_override = _material(Color("#1ca6a8"), true)
		add_child(pillar)

func _setup_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0, 1.0, 2.5)
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.height = 1.8
	capsule.radius = 0.38
	body.mesh = capsule
	body.material_override = _material(Color("#f4f7ff"))
	player.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.height = 1.8
	shape.radius = 0.38
	collision.shape = shape
	player.add_child(collision)
	add_child(player)

	camera = Camera3D.new()
	camera.current = true
	camera.fov = 65.0
	add_child(camera)

func _setup_npcs() -> void:
	for data in npcs:
		var npc := CharacterBody3D.new()
		npc.name = data["name"]
		npc.position = data["position"]
		npc.set_meta("dialogue_data", data)
		var body := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.height = 1.9
		capsule.radius = 0.42
		body.mesh = capsule
		body.material_override = _material(data["color"], true)
		npc.add_child(body)
		var collision := CollisionShape3D.new()
		var shape := CapsuleShape3D.new()
		shape.height = 1.9
		shape.radius = 0.42
		collision.shape = shape
		npc.add_child(collision)
		var name_tag := Label3D.new()
		name_tag.text = data["name"] + "  ·  " + data["role"]
		name_tag.position = Vector3(0, 1.5, 0)
		name_tag.font_size = 32
		name_tag.outline_size = 8
		name_tag.modulate = Color("#e9f5ff")
		npc.add_child(name_tag)
		add_child(npc)

func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	interaction_hint = Label.new()
	interaction_hint.position = Vector2(40, 40)
	interaction_hint.add_theme_font_size_override("font_size", 22)
	interaction_hint.add_theme_color_override("font_color", Color("#d9f1ff"))
	interaction_hint.text = "WASD 移动 · 靠近 NPC 后按 E 对话"
	layer.add_child(interaction_hint)

	dialogue_panel = Panel.new()
	dialogue_panel.position = Vector2(60, 500)
	dialogue_panel.size = Vector2(1160, 155)
	dialogue_panel.visible = false
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.06, 0.11, 0.94)
	panel_style.border_color = Color("#35d0d0")
	panel_style.set_border_width_all(2)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	dialogue_panel.add_theme_stylebox_override("panel", panel_style)
	layer.add_child(dialogue_panel)

	dialogue_title = Label.new()
	dialogue_title.position = Vector2(24, 18)
	dialogue_title.add_theme_font_size_override("font_size", 24)
	dialogue_title.add_theme_color_override("font_color", Color("#5eead4"))
	dialogue_panel.add_child(dialogue_title)

	dialogue_text = Label.new()
	dialogue_text.position = Vector2(24, 58)
	dialogue_text.size = Vector2(1090, 65)
	dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_text.add_theme_font_size_override("font_size", 22)
	dialogue_text.add_theme_color_override("font_color", Color("#f1f7ff"))
	dialogue_panel.add_child(dialogue_text)

func _move_player(_delta: float) -> void:
	if dialogue_panel != null and dialogue_panel.visible:
		player.velocity = Vector3.ZERO
		return
	var input_vector := Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	)
	if input_vector.length() > 1.0:
		input_vector = input_vector.normalized()
	var direction := Vector3(input_vector.x, 0, input_vector.y)
	player.velocity.x = direction.x * PLAYER_SPEED
	player.velocity.z = direction.z * PLAYER_SPEED
	player.velocity.y = 0.0
	player.move_and_slide()
	player.position.x = clamp(player.position.x, -10.5, 10.5)
	player.position.z = clamp(player.position.z, -10.5, 10.5)

func _update_camera() -> void:
	if player == null or camera == null:
		return
	var desired := player.global_position + Vector3(0, 4.6, 7.5)
	camera.global_position = camera.global_position.lerp(desired, 0.12)
	camera.look_at(player.global_position + Vector3(0, 0.8, 0), Vector3.UP)

func _update_nearby_npc() -> void:
	var closest: Node3D = null
	var closest_distance := INTERACTION_DISTANCE
	for child in get_children():
		if child is CharacterBody3D and child != player and child.has_meta("dialogue_data"):
			var distance := player.global_position.distance_to(child.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest = child
	nearby_npc = closest
	if dialogue_panel.visible:
		return
	if nearby_npc != null:
		interaction_hint.text = "靠近 %s · 按 E 对话" % nearby_npc.name
	else:
		interaction_hint.text = "WASD 移动 · 靠近 NPC 后按 E 对话"

func _open_or_advance_dialogue(npc: Node3D) -> void:
	var data: Dictionary = npc.get_meta("dialogue_data")
	if not dialogue_panel.visible:
		dialogue_lines.clear()
		for line in data["lines"]:
			dialogue_lines.append(str(line))
		dialogue_index = 0
		dialogue_panel.visible = true
		dialogue_title.text = "%s  ·  %s" % [data["name"], data["role"]]
		dialogue_text.text = dialogue_lines[dialogue_index] + "\n\n[E] 继续   [Esc] 关闭"
	elif dialogue_index + 1 < dialogue_lines.size():
		dialogue_index += 1
		dialogue_text.text = dialogue_lines[dialogue_index] + "\n\n[E] 继续   [Esc] 关闭"
	else:
		_close_dialogue()

func _close_dialogue() -> void:
	dialogue_panel.visible = false

func _material(color: Color, emissive := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 0.5
	return material
