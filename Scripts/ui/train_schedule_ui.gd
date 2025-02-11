extends PanelContainer

class_name TrainScheduleUI
var current_train: Train:
	set(value):
		current_train = value

var trainScene: PackedScene = preload("res://Scenes/train.tscn")
var trainSpriteScene: PackedScene = preload("res://Scenes/train_sprite.tscn")


# Which way the train is facing when placing with respect to the direction of _track_ point index
var train_placed_forward: bool = true

@onready var add_station_button: Button = $"VBoxContainer/Add Station"
@onready var train_name : Label = $VBoxContainer/TrainName
@onready var vBox : VBoxContainer = $VBoxContainer/Stops
var stop_element_scene: PackedScene = preload("res://Scenes/UI/stop_element.tscn")

# Groups are great; I want to fetch arbitrary unique nodes so gosh darn it let me do that
@onready var train_station_sprite: Sprite2D = get_tree().get_first_node_in_group("UIWorldItems").get_node("PlacingStationSprite")


func _on_request_train_ui_show(show_or_hide: bool) -> void:
	reset_state()
	if (show_or_hide):
		self.show()
		set_train_stop_visiblity(true)
		render()
	else:
		self.hide()
		train_station_sprite.visible = false
		set_train_stop_visiblity(false)

func _ready() -> void:
	train_station_sprite.visible = false

func reset_state() -> void:
	selecting_station_mode = false
	clear_children()

# Set From the world object
# Could also probably just set this from a global loader?
var track_intersection_searcher: TrackIntersectionSearcher 

var selecting_station_mode: bool = false

func set_train_stop_visiblity(visible_: bool) -> void:
	for stop: Stop in current_train.get_stops():
		stop.set_stop_visible(visible_)

func get_direction_sign() -> int:
	if (train_placed_forward):
		return 1
	else:
		return -1

#Can't use global mouse position because we're on a UI canvaslayer
func handle_input(event: InputEvent, global_mouse_position: Vector2) -> void:
	var track_point_info : TrackPointInfo
	var stop: Stop

	# Logic for placing a train-station
	if (selecting_station_mode):
		track_point_info = track_intersection_searcher.check_for_overlaps_at_position(global_mouse_position)
		if (track_point_info):
			stop = Stop.create_stop_for_point(track_point_info, current_train, train_placed_forward)
			if (stop):
				train_station_sprite.position = track_point_info.get_point()
				train_station_sprite.rotation = track_point_info.angle
				train_station_sprite.modulate = TrainBuilder.BLUE
		if !(track_point_info && stop):
			train_station_sprite.modulate = TrainBuilder.TRANSPARENT_RED
			train_station_sprite.position = global_mouse_position
			train_station_sprite.rotation = 0
		

	if (event.is_action_pressed("left_click")):	
		if (!selecting_station_mode):
			var trains: Array[Train] = track_intersection_searcher.get_train_collision_info(global_mouse_position)
			if (trains):
				if (trains.size() > 1):
					assert(false, "We have more than one train that we clicked on! This isn't great")

				current_train = trains[0]
				_on_request_train_ui_show(true)
		elif (selecting_station_mode):
			if (stop):
				current_train.add_stop(stop)
				selecting_station_mode = false
				train_station_sprite.visible = false
				render()



# We're going to UI it up like we're REACT, and simply re-render every time the UI changes. Makes it
# easier to reason about stuff and not have to constantly manage state
func clear_children() -> void:
	for child: Node in vBox.get_children():
		vBox.remove_child(child)
		child.queue_free()


func render() -> void:
	clear_children()
	if (current_train):
		train_name.text = current_train.name
		for stop_index: int in range(current_train.get_stops().size()):
			var stop: Stop = current_train.get_stops()[stop_index]
			var stop_element: StopElement = StopElement.new_stop_element(stop.stop_option[0].front_of_train.get_track_name() + "-" + stop.stop_option[0].front_of_train.get_track_pos_name(), current_train, stop_index)
			stop_element.connect("on_station_removed", _on_station_removed)
			vBox.add_child(stop_element)
			pass

# Should this really be here? Do we need to centralize the code here?
func _on_station_removed(train: Train, stop_index: int) -> void:
	train.remove_stop(stop_index)
	render()
	pass


func _on_add_station_pressed() -> void:
	selecting_station_mode = true
	train_station_sprite.visible = true



func _on_exit_button_pressed() -> void:
	_on_request_train_ui_show(false)
