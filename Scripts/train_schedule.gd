extends PanelContainer

class_name TrainScheduleUI
var current_train: Train:
	set(value):
		current_train = value

@onready var add_station_button = $"VBoxContainer/Add Station"
@onready var train_name : Label = $VBoxContainer/TrainName
@onready var vBox : VBoxContainer = $VBoxContainer/Stops
var stop_element_scene = preload("res://Scenes/UI/stop_element.tscn")

func _on_request_train_ui_show(show_or_hide: bool) -> void:
	if (show_or_hide):
		reset_state()
		self.show()
	else:
		self.hide()

func reset_state():
	selecting_station_mode = false
	clear_children()

# Set From the world object
# Could also probably just set this from a global loader?
var track_intersection_searcher: TrackIntersectionSearcher 

var selecting_station_mode = false

#Can't use global mouse position because we're on a UI canvaslayer
func handle_input(event: InputEvent, global_mouse_position: Vector2) -> void:
	if (event.is_action_pressed("left_click")):
		
		if (!selecting_station_mode):
			var trains: Array[Node2D] = track_intersection_searcher.get_train_collision_info(global_mouse_position)
			if (trains):
				if (trains.size() > 1):
					assert(false, "We have more than one train that we clicked on! This isn't great")

				current_train = trains[0]
				show()
				re_render()
		elif (selecting_station_mode):
			var track_point_info : TrackPointInfo = track_intersection_searcher.check_for_overlaps_at_position(global_mouse_position)
			if (track_point_info):
				current_train.add_stop(track_point_info)
				selecting_station_mode = false
				re_render()


# We're going to UI it up like we're REACT, and simply re-render every time the UI changes. Makes it
# easier to reason about stuff and not have to constantly manage state
func clear_children():
	for child in vBox.get_children():
		vBox.remove_child(child)
		child.queue_free()


func re_render():
	clear_children()
	if (current_train):
		pass
		train_name.text = current_train.name
		var size = current_train.stops.size()
		for stop_index in range(current_train.stops.size()):
			var stop = current_train.stops[stop_index]
			var stop_element = StopElement.new_stop_element(stop.track.name + "-" + str(stop.point_index), current_train, stop_index)
			stop_element.connect("on_station_removed", _on_station_removed)
			vBox.add_child(stop_element)
			pass

# We're assuming here we're only dealing with one train at a time
func _on_station_removed(train: Train):
	re_render()
	pass


func _on_add_station_pressed() -> void:
	selecting_station_mode = true
	pass


func _on_exit_button_pressed() -> void:
	hide() # Maybe should be reset state
