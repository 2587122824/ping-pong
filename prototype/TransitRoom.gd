extends Node3D

const PLAYER_SPEED := 5.0
const INTERACTION_DISTANCE := 3.2

var player: CharacterBody3D
var camera: Camera3D
var nearby_gate: Node3D
var interaction_hint: Label

func _ready() -> void:
	_setup_world()
	_setup_player()
	_setup_ui()

func _physics_process(_delta: float) -> void:
	_move_player()
	_update_camera()
	_update_nearby_gate()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E and nearby_gate != null:
			_enter_gate()

func _setup_world() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#160d2b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#c2a8ff")
	env.ambient_light_energy = 0.8
	environment.environment = env
	add_child(environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -25, 0)
	sun.light_color = Color("#d8c6ff")
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)

	var ground := StaticBody3D.new()
	var ground_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(24, 24)
	ground_mesh.mesh = plane
	ground_mesh.material_override = _material(Color("#241c42"))
	ground.add_child(ground_mesh)
	var ground_collision := CollisionShape3D.new()
	var ground_shape := BoxShape3D.new()
	ground_shape.size = Vector3(24, 0.2, 24)
	ground_collision.shape = ground_shape
	ground_collision.position.y = -0.1
	ground.add_child(ground_collision)
	add_child(ground)

	for position in [Vector3(-6, 2.0, -5), Vector3(6, 2.0, -5), Vector3(-6, 2.0, -9), Vector3(6, 2.0, -9)]:
		var pillar := MeshInstance3D.new()
		var pillar_mesh := BoxMesh.new()
		pillar_mesh.size = Vector3(0.35, 4.0, 0.35)
		pillar.mesh = pillar_mesh
		pillar.position = position
		pillar.material_override = _material(Color("#b766ff"), true)
		add_child(pillar)

	var platform := MeshInstance3D.new()
	var platform_mesh := CylinderMesh.new()
	platform_mesh.top_radius = 2.4
	platform_mesh.bottom_radius = 2.4
	platform_mesh.height = 0.2
	platform.mesh = platform_mesh
	platform.position = Vector3(0, 0.1, -5.8)
	platform.material_override = _material(Color("#4b3a78"))
	add_child(platform)

	var title := Label3D.new()
	title.text = "中转庭院\nTRANSIT COURT"
	title.position = Vector3(0, 4.5, -6.0)
	title.font_size = 48
	title.outline_size = 10
	title.modulate = Color("#f1e7ff")
	add_child(title)
	_setup_gate()

func _setup_gate() -> void:
	var gate := Node3D.new()
	gate.name = "TransitGate"
	gate.position = Vector3(0, 0, -6.0)
	gate.set_meta("target_scene", "res://Main.tscn")

	var frame_material := _material(Color("#b766ff"), true)
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.42, 3.5, 0.42)
	for z_offset in [-1.8, 1.8]:
		var post := MeshInstance3D.new()
		post.mesh = post_mesh
		post.material_override = frame_material
		post.position = Vector3(0, 1.75, z_offset)
		gate.add_child(post)

	var lintel := MeshInstance3D.new()
	var lintel_mesh := BoxMesh.new()
	lintel_mesh.size = Vector3(0.48, 0.45, 4.0)
	lintel.mesh = lintel_mesh
	lintel.material_override = frame_material
	lintel.position = Vector3(0, 3.5, 0)
	gate.add_child(lintel)

	var veil := MeshInstance3D.new()
	var veil_mesh := BoxMesh.new()
	veil_mesh.size = Vector3(0.06, 2.95, 3.25)
	veil.mesh = veil_mesh
	var veil_material := _material(Color("#d29cff"), true)
	veil_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	veil_material.albedo_color.a = 0.2
	veil_material.emission_energy_multiplier = 1.2
	veil.material_override = veil_material
	veil.position = Vector3(-0.04, 1.72, 0)
	gate.add_child(veil)

	var gate_tag := Label3D.new()
	gate_tag.text = "返回测试区\nRETURN GATE"
	gate_tag.position = Vector3(-0.3, 4.0, 0)
	gate_tag.font_size = 36
	gate_tag.outline_size = 8
	gate_tag.modulate = Color("#f1e7ff")
	gate.add_child(gate_tag)
	add_child(gate)
	gate.set_meta("interaction_position", gate.to_global(Vector3(-2.2, 1.0, 0)))

func _setup_player() -> void:
	player = CharacterBody3D.new()
	player.name = "TransitPlayer"
	player.position = Vector3(-2.5, 1.0, -6.0)
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

func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var title := Label.new()
	title.position = Vector2(40, 38)
	title.text = "中转庭院"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#f1e7ff"))
	layer.add_child(title)

	interaction_hint = Label.new()
	interaction_hint.position = Vector2(40, 82)
	interaction_hint.text = "WASD 移动 · 靠近返回大门后按 E"
	interaction_hint.add_theme_font_size_override("font_size", 19)
	interaction_hint.add_theme_color_override("font_color", Color("#d4c7ef"))
	layer.add_child(interaction_hint)


func _move_player() -> void:
	var input_vector := Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	)
	if input_vector.length() > 1.0:
		input_vector = input_vector.normalized()
	player.velocity = Vector3(input_vector.x * PLAYER_SPEED, 0, input_vector.y * PLAYER_SPEED)
	player.move_and_slide()
	player.position.x = clamp(player.position.x, -10.5, 10.5)
	player.position.z = clamp(player.position.z, -10.5, 10.5)

func _update_camera() -> void:
	var desired := player.global_position + Vector3(0, 4.6, 7.5)
	camera.global_position = camera.global_position.lerp(desired, 0.12)
	camera.look_at(player.global_position + Vector3(0, 0.8, 0), Vector3.UP)

func _update_nearby_gate() -> void:
	nearby_gate = null
	var gate := get_node_or_null("TransitGate")
	if gate != null:
		var distance: float = player.global_position.distance_to(gate.get_meta("interaction_position"))
		if distance < INTERACTION_DISTANCE:
			nearby_gate = gate
	if nearby_gate != null:
		interaction_hint.text = "区域传送门 · 按 E 传送至测试区"
	else:
		interaction_hint.text = "WASD 移动 · 靠近返回大门后按 E"

func _enter_gate() -> void:
	get_tree().change_scene_to_file("res://Main.tscn")

func _material(color: Color, emissive := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 0.7
	return material
