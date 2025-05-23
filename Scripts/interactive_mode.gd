extends Node3D

class_name InteractiveMode

# Set in world(this is dumb and you can't follow it in constructors and is going to be error-prone). TODO: Fix
var train_schedule_ui: TrainScheduleUI


var selecting_station_mode: bool = false

func hide_UI() -> void:
	train_schedule_ui.hide()

func handle_input(event: InputEvent) -> void:
	# Later we'll have submodes that will pass handling input around
	var mouse_position: OptionalVector2 = Utils.get_ground_mouse_position_vec2()
	if (mouse_position):
		train_schedule_ui.handle_input(event, mouse_position.value)
