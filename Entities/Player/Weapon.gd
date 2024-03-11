extends Node2D

@export var player: CharacterBody2D
@export_enum("Primary", "Secondary") var type: String = "Primary"
@export var sibling: Node2D
@export var data: Gun : set = set_data
@export var ui: CanvasLayer

@export var cursor: Node2D
@onready var sprite = $Sprite2D
@onready var bullet = preload("res://Entities/Bullet.tscn")
@onready var muzzle_flash = preload("res://Assets/Effects/MuzzleFlash.tscn")
@onready var rpm_timer = $RPMTimer
@onready var muzzle = $Muzzle

@export var camera: Camera2DPlus
@export var sound_component: SoundComponent

@onready var tween = get_tree().create_tween()

var ammo = 0


# Called when the node enters the scene tree for the first time.
func _ready():
	if data:
		set_data(data)
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if not data: 
		sprite.texture = null
		#ui.texture_rect.texture = null
		#ui.label.text = ''
		return
		
	sprite.texture = data.texture
	#ui.texture_rect.texture = data.texture
	#ui.label.text = str(ammo) + "/" + str(data.ammo)
	
	var direction: Vector2
	if InputManager.input_type == InputManager.CONTROLLER:
		var joy_dir = Vector2(Input.get_joy_axis(0,JOY_AXIS_LEFT_X), Input.get_joy_axis(0,JOY_AXIS_LEFT_Y))
		print(joy_dir.length())
		if abs(joy_dir.length()) >= 0.2:
			direction = joy_dir.normalized()
		else: direction = direction
	elif InputManager.input_type == InputManager.KBM:
		direction = player.global_position.direction_to(cursor.get_cursor_position())
	direction = direction.normalized()
	var rot = atan2(direction.y, direction.x)
	
	self.rotation_degrees = rad_to_deg(rot)
	
	if self.rotation_degrees > 360 or self.rotation_degrees < -360:
		self.rotation_degrees = 0
	
	if abs(self.rotation_degrees) > 90 and abs(self.rotation_degrees) < 270:
		sprite.flip_v = true
	else:
		sprite.flip_v = false
	
	if Input.is_action_pressed("%s_shoot" % type.to_lower()) and rpm_timer.time_left == 0:
		shoot()


func shoot():
	print("%s_shoot" % type.to_lower())
	if data.rpm == 0: return
	
	var direction: Vector2
	if InputManager.input_type == InputManager.CONTROLLER:
		var joy_dir = Vector2(Input.get_joy_axis(0,JOY_AXIS_LEFT_X), Input.get_joy_axis(0,JOY_AXIS_LEFT_Y))
		print(joy_dir.length())
		if abs(joy_dir.length()) >= 0.2:
			direction = joy_dir.normalized()
	elif InputManager.input_type == InputManager.KBM:
		direction = cursor.get_cursor_position() - self.global_position
	direction = -direction.normalized()
	
	camera.set_shake(data.shake_strength)
	
	if data.throwable and ammo <= 0:
		if ammo == 0: throw(direction.normalized())
		return
	
	rpm_timer.stop()
	rpm_timer.start(60/data.rpm)
	
	for i in range(data.bullets):
		var new_bullet = bullet.instantiate()
		new_bullet.top_level = true
		new_bullet.life_time = data.life_time
		new_bullet.global_position = muzzle.global_position
		new_bullet.velocity += self.get_parent().velocity
		new_bullet.direction = spread_vector(direction, data.spread)
		muzzle.add_child(new_bullet)
	
	var new_flash = muzzle_flash.instantiate()
	new_flash.position.x += 10
	self.add_child(new_flash)

	direction *= 75
	match data.recoil_type:
		"Set":
			player.velocity = Vector2(direction.x*data.recoil*0.75, direction.y*data.recoil)
		"Add":
			player.velocity += Vector2(direction.x*data.recoil*0.75, direction.y*data.recoil)
		"Multi":
			player.velocity *= Vector2(direction.x*data.recoil*0.75, direction.y*data.recoil)
	player.velocity.x = clamp(player.velocity.x, -data.velocity_cap.x, data.velocity_cap.x)
	player.velocity.y = clamp(player.velocity.y, -data.velocity_cap.y, data.velocity_cap.y)
	#print(player.velocity)
	if player.is_on_wall():
		player.velocity.x += player.get_wall_normal().x
	
	ammo -= 1
	if not data.throwable and ammo <=0: set_data()


func throw(direction):
	print('thrown')
	var new_bullet = bullet.instantiate()
	new_bullet.top_level = true
	new_bullet.life_time = data.life_time
	new_bullet.global_position = muzzle.global_position
	new_bullet.velocity += self.get_parent().velocity
	new_bullet.direction = spread_vector(direction, data.spread)
	new_bullet.throw_data = data
	muzzle.add_child(new_bullet)
	
	set_data()


func spread_vector(vector: Vector2, spread: float):
	var angle_rad = deg_to_rad(randf_range(-spread, spread)*20)
	var new_vector = Vector2(
		vector.x * cos(angle_rad) - vector.y * sin(angle_rad),
		vector.x * sin(angle_rad) + vector.y * cos(angle_rad)
	)
	return new_vector.normalized()


func set_data(new_data = null):
	if data and type == "Primary":
		#sibling.data=data
		#print('set new data on secondary')
		pass
	
	data = new_data
	print('set new data on primary')
	
	sound_component.play("Equip")
	
	if new_data:
		if sprite:
			sprite.texture = new_data.texture
		ammo = new_data.ammo
		#ammo = 500
	else:
		sprite.texture = null
		ammo = 0
