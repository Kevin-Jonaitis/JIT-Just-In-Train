extends Node

var ground : TileMapLayer;
var cellSize : int;


func setGround(_ground: TileMapLayer) -> void:
	self.ground = _ground
	# x and y size are the same, so just take x
	self.cellSize = _ground.tile_set.tile_size.x
func getGround() -> TileMapLayer:
	assert(ground, "Ground has not been defined yet!")
	return ground	
