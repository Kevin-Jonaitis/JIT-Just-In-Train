extends Node3D

class_name TrainCar

@onready var area3d : Area3D = $Area3D
@onready var boogie_front: MeshInstance3D = $Model/BoogieFront
@onready var boogie_back: MeshInstance3D = $Model/BoogieBack
@onready var model: MeshInstance3D = $Model
@onready var train: Train = get_parent().get_parent()

var progress: CarProgress
