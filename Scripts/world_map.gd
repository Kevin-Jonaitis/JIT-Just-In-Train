extends Node2D

## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	MapManager.setGround($Ground as TileMapLayer)
	pass # Replace with function body.
