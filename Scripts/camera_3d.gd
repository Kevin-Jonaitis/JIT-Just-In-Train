# Use W and S to move forward and backward.
# Use A and D to move left and right.
# Use Q and E to move up and down.
# Roll the scroll wheel to increase and decrease movement speed.
# Hold down the control key to rotate the camera. There's a slider in the editor to control mouse sensitivity.


class_name FreeLookCamera extends Camera3D

# Modifier keys' speed multiplier
const SHIFT_MULTIPLIER: float = 2.5
const ALT_MULTIPLIER: float = 1.0 / SHIFT_MULTIPLIER

@export_range(0.0, 1.0) var sensitivity: float = 0.25

# Mouse state
var _mouse_position: Vector2 = Vector2(0.0, 0.0)
var _total_pitch: float = 0.0

# Movement state
var _direction: Vector3 = Vector3(0.0, 0.0, 0.0)
var _velocity: Vector3 = Vector3(0.0, 0.0, 0.0)
var _acceleration: float = 30.0
var _deceleration: float = -10.0
var _vel_multiplier: float = 4.0

# Keyboard state
var _w: bool = false
var _s: bool = false
var _a: bool = false
var _d: bool = false
var _q: bool = false
var _e: bool = false
var _shift: bool = false
var _alt: bool = false

func _input(event: InputEvent) -> void:
	# Receives mouse motion
	if event is InputEventMouseMotion:
		_mouse_position = (event as InputEventMouseMotion).relative
	
	# Receives mouse button input
	if event is InputEventMouseButton:
		match (event as InputEventMouseButton).button_index:
			# Removed MOUSE_BUTTON_RIGHT handling - rotation is now tied to KEY_CONTROL
			MOUSE_BUTTON_WHEEL_UP: # Increases max velocity
				_vel_multiplier = clamp(_vel_multiplier * 1.1, 0.2, 20)
			MOUSE_BUTTON_WHEEL_DOWN: # Decereases max velocity
				_vel_multiplier = clamp(_vel_multiplier / 1.1, 0.2, 20)
	
	# Receives key input
	if event is InputEventKey:
		var event_cast: InputEventKey = event as InputEventKey
		match event_cast.keycode:
			KEY_CTRL:
				if event_cast.pressed:
					Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				else:
					Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			KEY_W:
				_w = event_cast.pressed
			KEY_S:
				_s = event_cast.pressed
			KEY_A:
				_a = event_cast.pressed
			KEY_D:
				_d = event_cast.pressed
			KEY_Q:
				_q = event_cast.pressed
			KEY_E:
				_e = event_cast.pressed
			KEY_SHIFT:
				_shift = event_cast.pressed
			KEY_ALT:
				_alt = event_cast.pressed

# Updates mouselook and movement every frame
func _process(delta: float) -> void:
	_update_mouselook()
	_update_movement(delta)

# Updates camera movement
func _update_movement(delta: float) -> void:
	# Computes desired direction from key states
	_direction = Vector3(
		(_d as float) - (_a as float), 
		(_e as float) - (_q as float),
		(_s as float) - (_w as float)
	)
	
	# Computes the change in velocity due to desired direction and "drag"
	# The "drag" is a constant acceleration on the camera to bring it's velocity to 0
	var offset: Vector3 = _direction.normalized() * _acceleration * _vel_multiplier * delta \
		+ _velocity.normalized() * _deceleration * _vel_multiplier * delta
	
	# Compute modifiers' speed multiplier
	var speed_multi: float = 1.0
	if _shift: speed_multi *= SHIFT_MULTIPLIER
	if _alt: speed_multi *= ALT_MULTIPLIER
	
	# Checks if we should bother translating the camera
	if _direction == Vector3.ZERO and offset.length_squared() > _velocity.length_squared():
		# Sets the velocity to 0 to prevent jittering due to imperfect deceleration
		_velocity = Vector3.ZERO
	else:
		# Clamps speed to stay within maximum value (_vel_multiplier)
		_velocity.x = clamp(_velocity.x + offset.x, -_vel_multiplier, _vel_multiplier)
		_velocity.y = clamp(_velocity.y + offset.y, -_vel_multiplier, _vel_multiplier)
		_velocity.z = clamp(_velocity.z + offset.z, -_vel_multiplier, _vel_multiplier)
	
		translate(_velocity * delta * speed_multi)

# Updates mouse look 
func _update_mouselook() -> void:
	# Only rotates mouse if the mouse is captured
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_mouse_position *= sensitivity
		var yaw: float = _mouse_position.x
		var pitch: float = _mouse_position.y
		_mouse_position = Vector2(0, 0)
		
		# Prevents looking up/down too far
		pitch = clamp(pitch, -90 - _total_pitch, 90 - _total_pitch)
		_total_pitch += pitch
	
		rotate_y(deg_to_rad(-yaw))
		rotate_object_local(Vector3(1,0,0), deg_to_rad(-pitch))
