extends Node2D

class_name InteractiveMode

# Set in world(this is dumb and you can't follow it in constructors and is going to be error-prone). TODO: Fix
var train_schedule_ui: TrainScheduleUI


var selecting_station_mode = false

func hide_UI():
	train_schedule_ui.hide()

func handle_input(event: InputEvent) -> void:
	# Later we'll have submodes that will pass handling input around
	train_schedule_ui.handle_input(event, get_global_mouse_position())
