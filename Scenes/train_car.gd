extends Node3D

class_name TrainCar

@onready var area3d : Area3D = $Area3D
@onready var boogie_front: MeshInstance3D = $Model/BoogieFront
@onready var boogie_back: MeshInstance3D = $Model/BoogieBack
@onready var model: MeshInstance3D = $Model
@onready var train: Train = get_parent().get_parent()

var progress: CarProgress


func set_position_and_rotation(car_progress: CarProgress) -> void:
	var center_position: Vector2 = car_progress.center.position
	# var front_pos: Vector2 = car_progress.front.position
	var front_boogie_pos: Vector2 = car_progress.front_boogie.position
	var back_boogie_pos: Vector2 = car_progress.back_boogie.position

	global_position = Vector3(center_position.x, Train.TRAIN_HEIGHT_OFFSET, center_position.y)
	rotation = Vector3(0, offset_rotation(car_progress.front.rotation), 0)
	
	# THESE NEED TO BE SET AFTER THE GLOBAL TRAINCAR POSITION; if we do it before, we'll get some weird undefined behavior about double applying location
	boogie_front.global_position = Vector3(front_boogie_pos.x, Train.TRAIN_HEIGHT_OFFSET + Train.BOGIE_HEIGHT, front_boogie_pos.y)
	boogie_front.global_rotation = Vector3(0, offset_rotation(car_progress.front_boogie.rotation), 0)
	
	boogie_back.global_position = Vector3(back_boogie_pos.x, Train.TRAIN_HEIGHT_OFFSET + Train.BOGIE_HEIGHT, back_boogie_pos.y)
	boogie_back.global_rotation = Vector3(0, offset_rotation(car_progress.back_boogie.rotation), 0)
	
static func offset_rotation(angle: float) -> float:
	return - angle - 3 * PI / 2

class CarPositionRotation:
	var position: Vector2
	var rotation: float

	func _init(position_: Vector2, rotation_: float) -> void:
		position = position_
		rotation = rotation_
