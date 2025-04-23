extends Node3D

class_name TrainCar

@onready var area3d : Area3D = $Area3D
@onready var boogie_front: MeshInstance3D = $Model/BoogieFront
@onready var boogie_back: MeshInstance3D = $Model/BoogieBack
@onready var model: MeshInstance3D = $Model
@onready var train: Train = get_parent().get_parent()
var car_type: CarType

const coal_car_area: PackedScene = preload("res://Assets/cars/coal_car_area.tscn")
const locomotive_car_area: PackedScene = preload("res://Assets/cars/locomotive_area.tscn")
const locomotive_model: PackedScene = preload("res://Assets/cars/locomotive.tscn")
const coal_model: PackedScene = preload("res://Assets/cars/wagon_coal.tscn")


var progress: CarProgress

enum CarType {COAL, LOCOMOTIVE}


func _init(car_type_: CarType) -> void:
	car_type = car_type_
	var car_model: MeshInstance3D
	var area: Area3D
	name = "TrainCar"
	if car_type == CarType.COAL:
		area = coal_car_area.instantiate()
		car_model = coal_model.instantiate()
	elif car_type == CarType.LOCOMOTIVE:
		area = locomotive_car_area.instantiate()
		car_model = locomotive_model.instantiate()
	else:
		assert(false, "Invalid car type")
	add_child(car_model)
	add_child(area)


func set_position_and_rotation(car_progress: CarProgress) -> void:
	var center_position: Vector2 = car_progress.center.position
	# var front_pos: Vector2 = car_progress.front.position
	var front_boogie_pos: Vector2 = car_progress.front_boogie.position
	var back_boogie_pos: Vector2 = car_progress.back_boogie.position

	global_position = Vector3(center_position.x, Train.TRAIN_HEIGHT_OFFSET, center_position.y)
	rotation = Vector3(0, offset_rotation(car_progress.center.rotation), 0)
	
	# THESE NEED TO BE SET AFTER THE GLOBAL TRAINCAR POSITION; if we do it before, we'll get some weird undefined behavior about double applying location
	boogie_front.global_position = Vector3(front_boogie_pos.x, Train.TRAIN_HEIGHT_OFFSET + Train.BOGIE_HEIGHT, front_boogie_pos.y)
	boogie_front.global_rotation = Vector3(0, offset_rotation(car_progress.front_boogie.rotation), 0)
	
	boogie_back.global_position = Vector3(back_boogie_pos.x, Train.TRAIN_HEIGHT_OFFSET + Train.BOGIE_HEIGHT, back_boogie_pos.y)
	boogie_back.global_rotation = Vector3(0, offset_rotation(car_progress.back_boogie.rotation), 0)

static func offset_rotation(angle: float) -> float:
	return - angle - 3 * PI / 2



func get_car_length() -> float:

	if car_type == TrainCar.CarType.COAL:
		return Train.COAL_CAR_LENGTH
	elif car_type == TrainCar.CarType.LOCOMOTIVE:
		return Train.LOCOMOTIVE_CAR_LENGTH
	else:
		assert(false, "Invalid car type")
		return 0.0



class CarPositionRotation:
	var position: Vector2
	var rotation: float

	func _init(position_: Vector2, rotation_: float) -> void:
		position = position_
		rotation = rotation_
