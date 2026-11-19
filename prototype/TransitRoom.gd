extends Node3D

const PLAYER_SPEED := 5.0

var player: CharacterBody3D
var camera: Camera3D
var return_panel: Panel

func _ready() -> void:
	_setup_world()
	_setup_player()
	_setup_ui()

func _physics_process(_delta: float) -> void:
	_move_player()
	_update_camera()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_return_to_test_area()

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

func _setup_player() -> void:
	player = CharacterBody3D.new()
	player.name = "TransitPlayer"
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

func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var title := Label.new()
	title.position = Vector2(40, 38)
	title.text = "中转庭院"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#f1e7ff"))
	layer.add_child(title)

	var hint := Label.new()
	hint.position = Vector2(40, 82)
	hint.text = "WASD 移动 · 这里是大门连接的第二场景 · 按 Esc 返回测试区"
	hint.add_theme_font_size_override("font_size", 19)
	hint.add_theme_color_override("font_color", Color("#d4c7ef"))
	layer.add_child(hint)

	return_panel = Panel.new()
	return_panel.position = Vector2(40, 610)
	return_panel.size = Vector2(360, 70)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.04, 0.16, 0.92)
	panel_style.border_color = Color("#b766ff")
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(8)
	return_panel.add_theme_stylebox_override("panel", panel_style)
	layer.add_child(return_panel)

	var return_button := Button.new()
	return_button.position = Vector2(16, 14)
	return_button.size = Vector2(328, 42)
	return_button.text = "返回测试区  [Esc]"
	return_button.pressed.connect(_return_to_test_area)
	return_panel.add_child(return_button)

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

func _return_to_test_area() -> void:
	get_tree().change_scene_to_file("res://Main.tscn")

func _material(color: Color, emissive := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 0.7
	return material
