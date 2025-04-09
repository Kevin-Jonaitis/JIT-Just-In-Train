extends Node3D

class_name MouseTracker3D

@onready var trackBuilder3D: TrackBuilder3D = $TrackBuilder3D
@onready var train_builder: TrainBuilder = $TrainBuilder
@onready var interactive_mode: InteractiveMode = $InteractiveMode

var drawableFunctionsToCallLater: Array[Callable] = []

# true = place track, false = place train
var track_or_train: bool = true

# Interact_or_edit mode
var interact_or_edit_mode: bool = false
const MIN_TURN_RADIUS_STEP: float = 1
# func _ready() -> void:
# 	train_builder.set_train_builder_disabled()

@onready var mouse_sphere: MeshInstance3D = $MouseSphere


func _unhandled_input(event: InputEvent) -> void:

	if (event.is_action_pressed("interact_mode")):
		interact_or_edit_mode = !interact_or_edit_mode #Toggable, we should change this later to be more user friendly

	if (event.is_action_pressed("place_train_or_track")): # Maybe this could go top level?
		track_or_train = !track_or_train

	if (interact_or_edit_mode):
		handle_interact_mode(event)
	else:
		handle_edit_mode(event)

# TODO: There's got to be a better way to do this
func hide_editor_modes() -> void:
	trackBuilder3D.visible = false
	trackBuilder3D.cancel_track()
	train_builder.set_train_builder_disabled()

func hide_interact_mode() -> void:
	interactive_mode.hide_UI()
	
func handle_interact_mode(event: InputEvent) -> void:
	hide_editor_modes()
	interactive_mode.handle_input(event)
	pass

func handle_edit_mode(event: InputEvent) -> void:
	pass
	# hide_interact_mode()
	
	if (track_or_train):
		trackBuilder3D.drawableFunctionsToCallLater.clear()
		trackBuilder3D.find_nearest_grid_and_tangents(Utils.get_ground_mouse_position_vec2())
		trackBuilder3D.visible = true
		# train_builder.set_train_builder_disabled()
		# trackBuilder3D.queue_redraw()
	# elif (!track_or_train):
	# 	trackBuilder.visible = false
	# 	train_builder.set_train_builder_enabled()		

	if (track_or_train):
		handle_track_building(event)
	# else:
	# 	train_builder.handle_input(event)

func handle_track_building(event: InputEvent) -> void:
	draw_sphere_for_mouse_position()
	if  (not (event is InputEventMouseMotion || event.is_action_type())):
		return
	if (event is InputEventMouseMotion):
		trackBuilder3D.find_nearest_grid_and_tangents(Utils.get_ground_mouse_position_vec2())
	# if (event is InputEventMouseMotion):
	if (event.is_action_pressed("left_click")):
		if (trackBuilder3D.trackStartingPosition == null && trackBuilder3D.can_place_point):
			trackBuilder3D.intialize_and_set_start_point()
		elif (trackBuilder3D.trackStartingPosition != null && trackBuilder3D.validTrack && trackBuilder3D.can_place_point):
				trackBuilder3D.solidifyTrack()
				return; # We don't want to call build track again
	elif (event.is_action_pressed("track_mode")):
		trackBuilder3D.track_mode_flag = !trackBuilder3D.track_mode_flag
	elif (event.is_action_pressed("curve_type")):
		trackBuilder3D.curve_type_flag = !trackBuilder3D.curve_type_flag
	elif (event.is_action_pressed("cancel")):
		trackBuilder3D.cancel_track()
	elif (event.is_action_pressed("flip_track_direction")):
		trackBuilder3D.flip_track_direction()
	elif(event.is_action("increase_size") && event.is_pressed()):
		trackBuilder3D.minAllowedRadius += MIN_TURN_RADIUS_STEP
	elif(event.is_action("decrease_size") && event.is_pressed()):
		trackBuilder3D.minAllowedRadius -= MIN_TURN_RADIUS_STEP

	## Always recompute the track on any inputEvent
	if (trackBuilder3D.trackStartingPosition):
		trackBuilder3D.compute_path()
	
# func _draw() -> void:
# 	for function: Callable in drawableFunctionsToCallLater:
# 		function.call()
# 	drawableFunctionsToCallLater.clear()

func draw_sphere_for_mouse_position() -> void:
	var maybe_mouse_pos: OptionalVector2 = Utils.get_ground_mouse_position_vec2()
	if (maybe_mouse_pos):
		var mouse_pos: Vector2 = maybe_mouse_pos.value
		mouse_sphere.global_position = Vector3(mouse_pos.x, 0.1, mouse_pos.y)
