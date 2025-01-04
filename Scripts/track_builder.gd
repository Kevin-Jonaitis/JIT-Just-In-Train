extends RefCounted
class_name TrackBuilder


# Properties for the TrackBuilder
var wallToHighlight: Array = [Vector2(), Vector2()]
var centerPointToHighlight: Vector2
var highlightColor = Color(0, 0, 255, 0.5)
var circleColor = Color(0, 0, 255)

var currentPointTangents: Array = [Vector2(), Vector2()]
var startPointTangents: Array = [Vector2(), Vector2()]

var trackStartingPosition = null
var trackEndingPosition = null
var trackStartingControlPoint = null
var trackEndingControlPoint = null
# If it's possible to build the track given the starting and ending positions and directions
var validTrack: bool = false

## Track Settings
var tangentSwitchEndpoint: bool = false
var tangentSwitchStartpoint: bool = false
## Wether we should find the first viable curve and stop or find the best curve(given the constraints)
var track_mode_flag: bool = false

# Switches between minimum tangent and minimum radius modes
var arrow_start : Sprite2D
var arrow_end : Sprite2D
var track: Track

# Sharpest turning radius and other constants
# var minAllowedRadius = 45
var minAllowedRadius = 100:
	set(value):
		if value < 15:
			return
		if value > 1000:
			return
		minAllowedRadius = value
		
var ratio_distance_to_baked_points = 5


# Preloaded assets
const trackPreloaded = preload("res://Scenes/track.tscn")
const track_direction_arrow = preload("res://Assets/arrow_single.png");


var curve_type_flag: bool = true:
	set(value):
		curve_type_flag = value
		if (is_instance_valid(track)):
			track.update_stored_curves(curve_type_flag)


var tracks: Node

func _init(tracks_: Node):
	tracks = tracks_
	arrow_start = Sprite2D.new()
	arrow_end = Sprite2D.new()
	arrow_start.scale = Vector2(0.03, 0.03)
	arrow_end.scale = Vector2(0.03, 0.03)
	arrow_start.set_texture(track_direction_arrow)
	arrow_end.set_texture(track_direction_arrow)
	create_track_node_tree()

# Setups a new track(with arrows)
# Should be called after a cancel or solidify of a track, to create a new one
func create_track_node_tree():
	track = trackPreloaded.instantiate()
	track.track_visual_component
	track.name = "UserPlacedTrack"
	tracks.add_child(arrow_start)
	tracks.add_child(arrow_end)
	track.update_stored_curves(curve_type_flag) ## No better way to instantiate unforutenly
	tracks.add_child(track) 
	arrow_start.visible = false
	arrow_end.visible = false
	track.visible = false

func flip_track_direction():
	if (!trackEndingPosition):
		tangentSwitchStartpoint = !tangentSwitchStartpoint
	elif  (trackStartingPosition && trackEndingPosition):
		tangentSwitchEndpoint = !tangentSwitchEndpoint

# Calculate the unit tangents
func calculate_tangents(point_a: Vector2, point_b: Vector2) -> Array[Vector2]:
	# Direction vector
	var direction = point_b - point_a

	# Left and right normals
	var left_normal = Vector2(-direction.y, direction.x).normalized()
	var right_normal = Vector2(direction.y, -direction.x).normalized()

	return [
		left_normal,
		right_normal
	]


func rotate_sprite(unit_tangent: Vector2, sprite: Sprite2D):
	sprite.rotation = unit_tangent.angle()


func intialize_and_set_start_point():
	set_start_info()

func set_start_info():
	trackStartingPosition = centerPointToHighlight
	startPointTangents = currentPointTangents
	trackStartingControlPoint = startPointTangents[0] if tangentSwitchStartpoint else startPointTangents[1];
	track.visible = true


#
func solidifyTrack():
	reset_track_builder()
	create_track_node_tree()

# We want to reset most things, but leave things like
# arrow direction and track type intack for next track placement
func reset_track_builder():
	if (track.dubins_path):
		track.dubins_path.clear_drawables()
	# if (track):
	tracks.remove_child(arrow_start)
	tracks.remove_child(arrow_end)
	track.track_visual_component.modulate = Color(1,1,1,1)
	trackStartingPosition = null
	trackEndingPosition = null
	trackStartingControlPoint = null
	trackEndingControlPoint = null


func cancel_track():
	if (!is_instance_valid(track)):
		return
	reset_track_builder()

	track.queue_free()
	track = null	

	create_track_node_tree()
	
func find_nearest_grid_and_tangents(event: InputEventMouseMotion):	
	var mousePosition = event.position
	var tileGridPosition = MapManager.getGround().local_to_map(event.position)
	var tileCenterLocalPosition = MapManager.getGround().map_to_local((tileGridPosition))

	var halfDistance = MapManager.cellSize / 2.0
	var closetWallAndMidpoint = get_closest_wall_and_midpoint(mousePosition, tileCenterLocalPosition, halfDistance)	
	wallToHighlight = closetWallAndMidpoint[0];
	centerPointToHighlight = closetWallAndMidpoint[1];
	currentPointTangents = calculate_tangents(wallToHighlight[0], wallToHighlight[1])
	if (!trackStartingPosition):
		update_arrow_start(centerPointToHighlight, currentPointTangents)


func update_arrow_end() -> void:
	arrow_end.visible = true
	# Determine the arrow's tangent point, it's opposite of the track tangent
	var arrowPoint = currentPointTangents[0] if !tangentSwitchEndpoint else currentPointTangents[1]
	# Rotate the arrow sprite to point in the opposite direction of the track's tangent
	rotate_sprite(trackEndingControlPoint * -1, arrow_end)
	arrow_end.position = trackEndingPosition + (arrowPoint * (MapManager.cellSize / 2.0))


func update_arrow_start(position: Vector2, tangents: Array[Vector2]) -> void:
	arrow_start.visible = true
	# Determine the arrow's tangent point, it's opposite of the track tangent
	var arrowPoint = tangents[0] if !tangentSwitchStartpoint else tangents[1]
	rotate_sprite(-1 * arrowPoint, arrow_start)
	arrow_start.position = position + (arrowPoint * (MapManager.cellSize / 2.0))


func get_closest_wall_and_midpoint(mouse_position: Vector2, tile_center: Vector2, half_distance: int) -> Array:
	# Define the wall edges as start and end points
	var walls = [
		[tile_center + Vector2(-half_distance, -half_distance), tile_center + Vector2(-half_distance, half_distance)],   # Left wall
		[tile_center + Vector2(half_distance, -half_distance), tile_center + Vector2(half_distance, half_distance)],    # Right wall
		[tile_center + Vector2(-half_distance, -half_distance), tile_center + Vector2(half_distance, -half_distance)],  # Top wall
		[tile_center + Vector2(-half_distance, half_distance), tile_center + Vector2(half_distance, half_distance)]     # Bottom wall
	]

	# Find the closest wall manually
	var closest_wall = null
	var smallest_distance = INF
	var closest_midpoint = Vector2.ZERO
	for wall in walls:
		var wall_midpoint = (wall[0] + wall[1]) / 2.0
		var distance = wall_midpoint.distance_to(mouse_position)
		if distance < smallest_distance:
			smallest_distance = distance
			closest_wall = wall
			closest_midpoint = wall_midpoint

	return [closest_wall, closest_midpoint]


func build_track() -> void:
	# Update ending position
	trackEndingPosition = centerPointToHighlight
	trackEndingControlPoint = currentPointTangents[0] if tangentSwitchEndpoint else currentPointTangents[1];	

	update_arrow_start(trackStartingPosition, startPointTangents)
	update_arrow_end()

	var valid = track.compute_track(
		trackStartingPosition, 
		trackStartingControlPoint, 
		trackEndingPosition, 
		trackEndingControlPoint, 
		minAllowedRadius,
		track_mode_flag,
		curve_type_flag)

	self.validTrack = valid
	
	if valid:
		track.track_visual_component.modulate = Color8(0, 77, 255, int(0.79 * 255))  # Half-transparent blue
	else:
		track.track_visual_component.modulate = Color(1, 0, 0, 0.5)  # Half-transparent red
