extends Node3D

class_name TrainCar

@onready var area3d : Area3D = $Area3D
@onready var boogie_front: MeshInstance3D = $Model/BoogieFront
@onready var boogie_back: MeshInstance3D = $Model/BoogieBack
@onready var model: MeshInstance3D = $Model
@onready var train: Train = get_parent().get_parent()

var progress: CarProgress

func set_position_and_rotation(position_: Vector2, rotation_: float) -> void:
	position = Vector3(position_.x, 0.666, position_.y)
	rotation = Vector3(0, offset_rotation(rotation_), 0)
	#TODO: modify all the following cars

static func offset_rotation(angle: float) -> float:
	return - angle - 3 * PI / 2
