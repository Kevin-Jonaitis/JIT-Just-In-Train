extends Node2D

## gotta be a better way to organize this than to grab get_parent()...
@onready var ground : TileMapLayer = get_parent()
var transparent_red = Color(255, 0, 0, 0.15)
	
func _draw():
	draw_tilemap_grid()
		
		
#draw_multiline  
# https://docs.godotengine.org/en/stable/classes/class_canvasitem.html#class-canvasitem-method-draw-multiline

func draw_tilemap_grid():
	# Get the TileMap's cell size
	# x and y size are the same, so just take x
	var cell_size = ground.tile_set.tile_size.x
	var worldDimensions = ground.get_used_rect().size
	print("THE RECTANGLE SIZE IS", ground.get_used_rect().size)
	print("THE CELL SIZE IS", cell_size)
	# Calculate the map size (adjust based on your map's dimensions)
	var map_size_in_squares = ground.get_used_rect().size
	var map_size_in_pixels = Vector2(worldDimensions.x * cell_size, worldDimensions.y * cell_size)
	print ("MAP_SIZE IS", map_size_in_pixels)
	# Draw gridlines for the TileMap
	
	## should replace with draw_line_multiple
	for x in range(map_size_in_squares.x + 1):
		draw_line(Vector2(x * cell_size,0), Vector2(x * cell_size, cell_size * map_size_in_squares.y), transparent_red, 2)
		
	for y in range(map_size_in_squares.y + 1):
		draw_line(Vector2(0, y * cell_size), Vector2(cell_size * map_size_in_squares.x, y * cell_size), transparent_red, 2)
