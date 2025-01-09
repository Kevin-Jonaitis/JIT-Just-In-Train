extends RefCounted
class_name TrackBuilder


static var track_counter = 0  # Initialize the counter


var highlightColor = Color(0, 0, 255, 0.5)
var circleColor = Color(0, 0, 255)

var currentTrackPlacePoint: Vector2
# Line that follows the track at the point
var currentPointTangent: Vector2

var trackStartingPosition = null
var trackEndingPosition = null
var trackStartingControlPoint = null
var trackEndingControlPoint = null
# If it's possible to build the track given the starting and ending positions and directions
var validTrack: bool = false

## Track Settings
var tangentSwitchEndpoint: bool = false
var tangentSwitchStartpoint: bool = false

# If we are currently sticking to a starting track for the direction
# Vector2 or null
var closet_track_tangent = null
## Wether we should find the first viable curve and stop or find the best curve(given the constraints)
var track_mode_flag: bool = false

# Switches between minimum tangent and minimum radius modes
var mouse_tracker: Node2D
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

func _init(tracks_: Node, mouse_tracker_node_: Node2D):
	tracks = tracks_
	mouse_tracker = mouse_tracker_node_
	arrow_start = Sprite2D.new()
	arrow_end = Sprite2D.new()
	arrow_start.scale = Vector2(0.03, 0.03)
	arrow_end.scale = Vector2(0.03, 0.03)
	arrow_start.z_index = 1000 # Just set them on top always. Hacky. I should probably just have these be actual nodes
	arrow_end.z_index = 1000
	arrow_start.set_texture(track_direction_arrow)
	arrow_end.set_texture(track_direction_arrow)
	create_track_node_tree()

# Setups a new track(with arrows)
# Should be called after a cancel or solidify of a track, to create a new one
func create_track_node_tree():
	track = trackPreloaded.instantiate()
	track.track_visual_component
	track.name = "UserPlacedTrack-" + str(track_counter)
	track_counter += 1
	mouse_tracker.add_child(arrow_start)
	mouse_tracker.add_child(arrow_end)
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
	else:
		push_error("Invalid state, we shouldn't have both a start and end position and flipping the track")

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
	trackStartingPosition = currentTrackPlacePoint
	trackStartingControlPoint = currentPointTangent
	track.visible = true	


func solidifyTrack():
	track.area2d.solidfy_collision_area()
	track.area2d.set_collision_layer_value(1, true)
	track.area2d.set_collision_mask_value(1, false) # Should be nothing
	var test = track.area2d.get_collision_layer()

	reset_track_builder()
	create_track_node_tree()


# We want to reset most things, but leave things like
# arrow direction and track type intack for next track placement
func reset_track_builder():
	if (track.dubins_path):
		track.dubins_path.clear_drawables()
	mouse_tracker.remove_child(arrow_start)
	mouse_tracker.remove_child(arrow_end)
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
	
func find_nearest_grid_and_tangents(mousePos: Vector2):
	var mousePosition = mousePos
	var overlapping_track = mouse_tracker.track_intersector_searcher.check_for_overlap_track()
	# Used if we need to snap to a track start/end
	var snap_tangent = null
	var tangents

	# Find the closet track point. If the track endpoint is within our radius, we should "stick" to it. 
	# and set the tangent to point away from the track
	# Otherwise, if we did find a track point, we should set the tanget according to the angle at that point and
	# using our tanget switch
	# OTHERWISE, just look for the closest grid wall and snap to that

	if (overlapping_track && (overlapping_track["is_start"] || overlapping_track["is_end"])):
		draw_walls_and_centerpoint(overlapping_track["point"], overlapping_track["angle"])
		currentTrackPlacePoint = overlapping_track["point"]
		# We need to snap the tangent in the opposite direction of the track.
		var reverser;
		if overlapping_track["is_start"]:
			reverser = -1
		else:
			reverser = 1

		snap_tangent = reverser * Vector2.from_angle(overlapping_track["angle"])
	elif(overlapping_track):
		draw_walls_and_centerpoint(overlapping_track["point"], overlapping_track["angle"])
		currentTrackPlacePoint = overlapping_track["point"]
		closet_track_tangent = Vector2.from_angle(overlapping_track["angle"])
		tangents = [closet_track_tangent, -1 * closet_track_tangent]
	else:
		var centerpoint_and_tangets = draw_wall_and_calculate_centerpoint_and_tangent(mousePosition)
		currentTrackPlacePoint = centerpoint_and_tangets[0]
		tangents = centerpoint_and_tangets[1]
	
	if (snap_tangent):
		currentPointTangent = snap_tangent
	else:
		determine_tangent_from_switches(tangents)


	if (!trackStartingPosition):
		update_arrow_start()

func determine_tangent_from_switches(tangents: Array):
	if (!trackStartingPosition):
		currentPointTangent = tangents[0] if tangentSwitchStartpoint else tangents[1]
	elif(trackStartingPosition && trackEndingPosition):
		currentPointTangent = tangents[0] if tangentSwitchEndpoint else tangents[1]
	else:
		printerr("Unknown state, tracking starting position and track ending position both set")

func draw_walls_and_centerpoint(point_position: Vector2, theta: float):
	# Convert angle to unit vector
	var direction = Vector2.from_angle(theta)
	
	# Calculate perpendicular vector for wall direction
	var perpendicular = Vector2(-direction.y, direction.x)
	
	# Use mouse position directly as center point
	currentTrackPlacePoint = point_position
	
	# Calculate wall endpoints using half cell size
	var halfDistance = MapManager.cellSize / 2.0
	var wallStart = point_position + (perpendicular * halfDistance)
	var wallEnd = point_position - (perpendicular * halfDistance)
	
	# Draw debug visuals
	mouse_tracker.drawableFunctionsToCallLater.append(func(): mouse_tracker.draw_line(wallStart, wallEnd, highlightColor, 3))
	mouse_tracker.drawableFunctionsToCallLater.append(func(): mouse_tracker.draw_circle(currentTrackPlacePoint, 4, highlightColor, false, 4))
	

func draw_wall_and_calculate_centerpoint_and_tangent(mousePos: Vector2):
	var track_position = null 
	var wallToHighlight  = null
	var tileGridPosition = MapManager.getGround().local_to_map(mousePos)
	var tileCenterLocalPosition = MapManager.getGround().map_to_local((tileGridPosition))

	var halfDistance = MapManager.cellSize / 2.0
	var closetWallAndMidpoint = get_closest_wall_and_midpoint(mousePos)	
	wallToHighlight = closetWallAndMidpoint[0];
	track_position = closetWallAndMidpoint[1];

	mouse_tracker.drawableFunctionsToCallLater.append(func(): mouse_tracker.draw_line(wallToHighlight[0], wallToHighlight[1],highlightColor, 3))
	mouse_tracker.drawableFunctionsToCallLater.append(func(): mouse_tracker.draw_circle(track_position, 4, highlightColor, false, 4))
	var tangents = calculate_tangents(wallToHighlight[0], wallToHighlight[1])

	return [track_position, tangents]
	

func update_arrow_end() -> void:
	arrow_end.visible = true
	# Determine the arrow's tangent point, it's opposite of the track tangent
	var arrowPoint = -1 * currentPointTangent
	# Rotate the arrow sprite to point in the opposite direction of the track's tangent
	rotate_sprite(trackEndingControlPoint * -1, arrow_end)
	arrow_end.position = trackEndingPosition + (arrowPoint * (MapManager.cellSize / 2.0))


func update_arrow_start() -> void:
	arrow_start.visible = true
	# Determine the arrow's tangent point, it's opposite of the track tangent
	var arrowPoint = -1 * currentPointTangent
	rotate_sprite(-1 * arrowPoint, arrow_start)
	arrow_start.position = currentTrackPlacePoint + (arrowPoint * (MapManager.cellSize / 2.0))


func get_closest_wall_and_midpoint(mouse_position: Vector2) -> Array:
	var tileGridPosition = MapManager.getGround().local_to_map(mouse_position)
	var tile_center = MapManager.getGround().map_to_local(tileGridPosition)
	var half_distance = MapManager.cellSize / 2.0
	
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
	trackEndingPosition = currentTrackPlacePoint
	trackEndingControlPoint = currentPointTangent

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

# Returns a tuple of [point, direction(as a normalized vector2)] or null
func get_closest_track_endpoints_and_directions(mouse_position: Vector2):
	var closest_point = null
	var closet_point_direction = null
	var smallest_distance = INF
	var track_children = tracks.get_children()
	for track in track_children:
		var points_and_endpoints = track.get_endpoints_and_directions()
		for i in range(points_and_endpoints.size()):
			var distance = points_and_endpoints[i][0].distance_to(mouse_position)
			if distance < smallest_distance && distance < MapManager.cellSize / 2.0:
				smallest_distance = distance
				closest_point = points_and_endpoints[i][0]
				#Need to do this conversion because our codebase is inconsistent with unit vectors and theats
				closet_point_direction = Vector2.from_angle(points_and_endpoints[i][1])
				# We reverse the starting point to point _away_ from the track
				if (i == 0):
					closet_point_direction = -1 * closet_point_direction
	
	if (closest_point):
		return [closest_point, closet_point_direction]
	else:
		return null
