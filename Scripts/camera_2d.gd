extends Camera2D

var zoom_speed = 0.1  # Speed of zooming
var zoom_min = 0.5    # Minimum zoom level
var zoom_max = 2.0    # Maximum zoom level
var panning = true

@onready var viewport = get_viewport()

# This _input event needs to be called first before anything else so we stop
# processing events(we reuse the "left click" for example).
# We process nodes in "reverse" order, so put this noe at the bottom of the tree:
# https://www.reddit.com/r/godot/comments/112w2zt/notes_on_event_execution_order_with_a_side_dose/
func _input(event):
	if Input.is_action_pressed("zoom_in"):
		zoom_in()
		viewport.set_input_as_handled()
	elif Input.is_action_pressed("zoom_out"):
		zoom_out()
		viewport.set_input_as_handled()
	panning = false
	if Input.is_action_pressed("pan"):
		panning = true
		viewport.set_input_as_handled()
	if event is InputEventMouseMotion and panning:
		pan_camera(event)
		viewport.set_input_as_handled()

#https://forum.godotengine.org/t/how-to-zoom-camera-to-mouse/37348/3
# This still feels a bit... "off". But it'll work for now.
func zoom_in():
	var mouse_pos := get_global_mouse_position()
	var new_zoom = zoom + Vector2(zoom_speed, zoom_speed)
	zoom = Vector2(
		clamp(new_zoom.x, zoom_min, zoom_max),
		clamp(new_zoom.y, zoom_min, zoom_max)
	)
	
	var new_mouse_pos := get_global_mouse_position()
	position += mouse_pos - new_mouse_pos

func zoom_out():
	#var mouse_pos := get_global_mouse_position()
	var new_zoom = zoom - Vector2(zoom_speed, zoom_speed)
	zoom = Vector2(
		clamp(new_zoom.x, zoom_min, zoom_max),
		clamp(new_zoom.y, zoom_min, zoom_max)
	)

func pan_camera(event: InputEventMouseMotion):
	position -= event.relative / zoom
