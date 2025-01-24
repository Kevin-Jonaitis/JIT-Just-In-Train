extends HBoxContainer

class_name StopElement

@onready var stop_name : Label = $Panel/StopName
@onready var pane : Panel = $Panel
@onready var remove : Button = $Remove

var train_name: String
var train: Train
var stop_index: int

const scene: PackedScene = preload("res://Scenes/UI/stop_element.tscn")

func _ready() -> void:
	# Need to wait for children node to exist before we can set the name
	stop_name.text = train_name
	pass


static func new_stop_element(name_: String, train_: Train, stop_index_: int) -> StopElement:
	var stop_element: StopElement = scene.instantiate() as StopElement
	stop_element.train_name = name_
	stop_element.stop_index = stop_index_
	stop_element.train = train_
	return stop_element

func _on_remove_pressed() -> void:
	emit_signal("on_station_removed", train, stop_index)
