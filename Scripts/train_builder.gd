extends Node2D

class_name TrainBuilder

# We're doin' it the godot way...I guess 
signal add_new_train(train: Node2D)

var trainScene: PackedScene = preload("res://Scenes/train.tscn")
var train: Train

static var train_counter : int = 1

var enabled: bool = false  # Added type annotation

static var TRANSPARENT_RED: Color = Color(1, 0, 0, 0.5)  # Half-transparent red	
static var SOLID: Color = Color(1,1,1,1)  # Added type annotation
static var BLUE: Color = Color(0,0,1,0.7)  # Added type annotation

const TRACK_COLLISION_LAYER: int = 1
@onready var track_intersection_searcher: TrackIntersectionSearcher = TrackIntersectionSearcher.new(self)

var valid_train_placement: bool = false  # Added type annotation

func set_train_builder_enabled() -> void:  # Added return type
	train.visible = true

func set_train_builder_disabled() -> void:  # Added return type
	train.visible = false

func _ready() -> void:  # Added return type
	create_new_train(false)
	train.modulate = TRANSPARENT_RED

func create_new_train(visible_: bool) -> void:  # Added return type
	train = trainScene.instantiate()
	train.set_name_user("Train-" + str(train_counter))
	train_counter += 1
	train.visible = visible_
	valid_train_placement = false
	add_new_train.emit(train)

func handle_input(event: InputEvent) -> void:
	if (event.is_action_pressed("left_click") && valid_train_placement):
		place_train()

	var pointInfo: TrackPointInfo = track_intersection_searcher.check_for_overlaps_at_position(get_global_mouse_position())
	if (pointInfo):
		train.set_position_and_rotation(pointInfo.get_point(), pointInfo.angle)
		train.modulate = SOLID
		valid_train_placement = true
	else:
		train.modulate = TRANSPARENT_RED
		train.rotation = 0
		valid_train_placement = false
		train.set_position_and_rotation(get_global_mouse_position(), 0)
	
func place_train() -> void:  # Added return type
	train.modulate = SOLID
	train.front_car.area2d.collision_layer = Train.TRAIN_COLLISION_LAYER
	train.is_placed = true
	DeferredQueue.queue_calculate_turnaround(train) # As soon as it's placed set its turnaround loops
	create_new_train(true)
