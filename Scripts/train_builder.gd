extends Node2D

class_name TrainBuilder

# We're doin' it the godot way...I guess 
signal add_new_train(train: Node2D)

var trainScene: PackedScene = preload("res://Scenes/train.tscn")
var train: Sprite2D

var enabled = false

const TRANSPARENT_RED = Color(1, 0, 0, 0.5)  # Half-transparent red	
const SOLID = Color(1,1,1,1)


const TRACK_COLLISION_LAYER: int = 1
@onready var track_intersection_searcher: TrackIntersectionSearcher = TrackIntersectionSearcher.new(self)

var valid_train_placement = false

func set_train_builder_enabled():
	train.visible = true

func set_train_builder_disabled():
	train.visible = false

func _ready():
	create_new_train(false)
	train.modulate = TRANSPARENT_RED

func create_new_train(visible_: bool):
	train = trainScene.instantiate()
	train.visible = visible_
	train.is_placed = true
	valid_train_placement = false
	add_new_train.emit(train)

func handle_input(event: InputEvent) -> void:
	if (event.is_action_pressed("left_click") && valid_train_placement):
		place_train()

	var pointInfo: TrackPointInfo = track_intersection_searcher.check_for_overlaps_at_position(get_global_mouse_position())
	if (pointInfo):
		train.position = pointInfo.get_point()
		train.rotation = pointInfo.angle
		train.modulate = SOLID
		valid_train_placement = true
	else:
		train.modulate = TRANSPARENT_RED
		train.rotation = 0
		valid_train_placement = false
		train.position = get_global_mouse_position()
	
func place_train():
	train.modulate = SOLID
	train.area2d.collision_layer = Train.TRAIN_COLLISION_LAYER
	create_new_train(true)
