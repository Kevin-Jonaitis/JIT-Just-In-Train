extends Node2D
class_name TrackBuilder


static var track_counter = 0  # Initialize the counter


var highlightColor = Color(0, 0, 255, 0.5)
var circleColor = Color(0, 0, 255)

var currentTrackPlacePoint: Vector2
# Line that follows the track at the point
var currentPointTangent: Vector2

# In track placement, we sometimes move where the mouse position is based on to snap to things
# Because of this, we need to make sure we don't "double-snap". That is, snap once when a start position is selected,
# and then use that snapped position to snap to something else close(like a junction) when we calculate which thing
# to use when actually placing
# Therefore, we just keep track of Junctions/Overlaps we chose when we originally "snapped" and keep track of those 
# through placement calculations
var current_overlay: TrackOrJunctionOverlap # nullable

var trackStartingPosition = null
var starting_overlay: TrackOrJunctionOverlap # nullable
var trackEndingPosition = null
var ending_overlay: TrackOrJunctionOverlap # nullable
var trackStartAngle = null
var trackEndingAngle = null
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
var arrow_end : Sprite2D
var arrow_start : Sprite2D
var track: Track

@onready var track_intersection_searcher: TrackIntersectionSearcher = TrackIntersectionSearcher.new(self)
#TODO: This could be better
@onready var tracks: Tracks = $"../../Tracks"
@onready var trains: Trains = $"../../Trains"

var drawableFunctionsToCallLater: Array[Callable] = []


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

func _draw():
	for function in drawableFunctionsToCallLater:
		function.call()
	drawableFunctionsToCallLater.clear()

# Preloaded assets
const trackPreloaded = preload("res://Scenes/track.tscn")
const track_direction_arrow = preload("res://Assets/arrow_single.png")
const scene: PackedScene = preload("res://Scenes/track_builder.tscn")



var curve_type_flag: bool = true:
	set(value):
		curve_type_flag = value
		if (is_instance_valid(track)):
			track.update_stored_curves(curve_type_flag)


func _ready():
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
	# Need the counter, because (probably) this track is added before the other one is free, so there's a name conflict if we just use tempUserTrack
	track.name = "TempUserTrack" + str(track_counter)
	track_counter += 1
	add_child(arrow_start)
	add_child(arrow_end)
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
	starting_overlay = current_overlay
	trackStartAngle = currentPointTangent.angle()
	track.visible = true	


func solidifyTrack():
	setup_junctions() # This could be done in compute as well.
	track.name = "UserPlacedTrack-" + str(track_counter)
	track.area2d.solidify_collision_area()

	reset_track_builder()
	create_track_node_tree()

# Really, we should clean up our code so that when we instantiate a track, 
# we also instatiate it's curve type, as well as it's junctions(all at the same time).
# We should probably just ditch the bezier curve for now. It's so broken
func setup_junctions():
	if (track.bezier_curve):
		assert(false, "We haven't implemented junctions for bezier curves yet")
	elif (track.dubins_path):
		create_dubin_junctions()
	else:
		assert(false, "We should never get here")

func create_dubin_junctions():
	var startingJunction;
	if (starting_overlay):
		handle_track_joining_dubin(starting_overlay, true)
	else:
		var first_point = track.dubins_path.shortest_path._points[0]
		startingJunction = Junction.new_Junction(first_point, tracks, \
	Junction.NewConnection.new(track, true))
	
	# Check if our ending point overlaps our just-placed starting junction
	if (startingJunction):
		var point_to_check
		if (ending_overlay && ending_overlay.trackPointInfo):
			point_to_check = ending_overlay.trackPointInfo.get_point()
		if (!ending_overlay):
			point_to_check = track.dubins_path.shortest_path._points[-1]
		if (point_to_check && \
		track_intersection_searcher.is_junction_within_search_radius(startingJunction, point_to_check)):
			startingJunction.add_connection(Junction.NewConnection.new(track, false))
			return

	if (ending_overlay):
		handle_track_joining_dubin(ending_overlay, false)
	else:
		var last_point = track.dubins_path.shortest_path._points[-1]
		Junction.new_Junction(last_point, tracks, \
		Junction.NewConnection.new(track, false)) 
	

func handle_track_joining_dubin(overlap: TrackOrJunctionOverlap, is_start_of_new_track: bool):
	if (overlap.junction):
		overlap.junction.add_connection(Junction.NewConnection.new(track, is_start_of_new_track))
	elif (overlap.trackPointInfo):
		split_track_at_point(overlap.trackPointInfo, is_start_of_new_track)
	else:
		assert(false, "We should never get here, we should always have a junction or track point info if we're in this function")

	

# split existing track and update that existing track's junctions on the _far_ ends
	# have the directions go the same
	# but do NOT add junctions to the split track
# delete old track
# create a new junction for this _new_ track
# add the split track ends to the new junction
func split_track_at_point(trackPointInfo: TrackPointInfo, is_start_of_new_track: bool):	
	var split_tracks = create_split_track(trackPointInfo)
	var first_half = split_tracks[0]
	var second_half = split_tracks[1]
	var first_half_old_start_junction = trackPointInfo.track.start_junction
	# var second_half = create_split_track(trackPointInfo, false)
	var second_half_old_end_junction = trackPointInfo.track.end_junction
	# Update the references for all train stops to this new point
	trains.update_train_stops(trackPointInfo.get_point(), first_half, second_half)
	delete_track(trackPointInfo.track)

	# Start of first half
	first_half_old_start_junction.add_connection( \
	Junction.NewConnection.new(first_half, true))

	# End of first half + junction
	var intersection_junction = Junction.new_Junction(trackPointInfo.get_point(), tracks, \
	Junction.NewConnection.new(first_half, false))

	# Start of second half
	intersection_junction.add_connection(Junction.NewConnection.new(second_half, true))

	# The new track at the junction
	intersection_junction.add_connection(Junction.NewConnection.new(track, is_start_of_new_track))

	# End of the second half
	second_half_old_end_junction.add_connection(Junction.NewConnection.new(second_half, false))

func create_split_track(trackPointInfo: TrackPointInfo) -> Array[Track]:
	if (!trackPointInfo.track.dubins_path):
		assert(false, "We haven't implemented split for any other type of path")
		return []
	var new_tracks : Array[Track] = []
	var new_dubins_paths : Array[DubinPath] = trackPointInfo.track.dubins_path.shortest_path.split_at_point_index(trackPointInfo.point_index)
	for path in new_dubins_paths:
		var newTrack = trackPreloaded.instantiate()
		var name_suffix = newTrack.name + str(track_counter)
		newTrack.name = "SplitTrack-" + name_suffix
		track_counter += 1
		newTrack.update_stored_curves(curve_type_flag) ## No better way to instantiate unforutenly
		tracks.add_child(newTrack)
		newTrack.dubins_path.paths.append(path)
		newTrack.dubins_path.shortest_path = path
		newTrack.update_visual_and_collision_for_dubin_path()
		newTrack.area2d.solidify_collision_area()
		new_tracks.append(newTrack)
	return new_tracks
	

func delete_track(track_to_delete: Track):
	track_to_delete.start_junction.remove_track(track_to_delete)
	track_to_delete.end_junction.remove_track(track_to_delete)
	track_to_delete.queue_free()


# We want to reset most things, but leave things like
# arrow direction and track type intack for next track placement
func reset_track_builder():
	if (track.dubins_path):
		track.dubins_path.clear_drawables()
	remove_child(arrow_start)
	remove_child(arrow_end)
	track.track_visual_component.modulate = Color(1,1,1,1)
	trackStartingPosition = null
	trackEndingPosition = null
	starting_overlay = null
	ending_overlay = null
	trackStartAngle = null
	trackEndingAngle = null


func cancel_track():
	if (!is_instance_valid(track)):
		return
	reset_track_builder()

	track.queue_free()
	track = null	

	create_track_node_tree()
	
func find_nearest_grid_and_tangents(mousePos: Vector2):
	var mousePosition = mousePos
	current_overlay = track_intersection_searcher.check_for_junctions_or_track_at_position(mousePosition)
	var snap_tangent = null
	var tangents = null
	# Find the closet track point. If the track endpoint is within our radius, we should "stick" to it. 
	# and set the tangent to point away from the track
	# Otherwise, if we did find a track point, we should set the tanget according to the angle at that point and
	# using our tanget switch
	# OTHERWISE, just look for the closest grid wall and snap to that

	if (current_overlay):
		if (current_overlay.junction):
			draw_walls_and_centerpoint(current_overlay.junction.position, current_overlay.junction._angle)
			currentTrackPlacePoint = current_overlay.junction.position

			# If there is only one track on the junction, and we don't have a starting position yet,
			# snap to that junction
			# Because junctions with 1 line always have an angle that faces _away_ from that line(because
			# that's how they're constructed), we can just reuse that snap direction.
			if (current_overlay.junction.lines.size() == 1 && !trackStartingPosition):
				snap_tangent = Vector2.from_angle(current_overlay.junction._angle)
			else:
				tangents = [Vector2.from_angle(current_overlay.junction._angle),
				Vector2.from_angle(current_overlay.junction._opposite_angle)]
		elif(current_overlay.trackPointInfo):
			draw_walls_and_centerpoint(current_overlay.trackPointInfo.get_point(), current_overlay.trackPointInfo.angle)
			currentTrackPlacePoint = current_overlay.trackPointInfo.get_point()
			closet_track_tangent = Vector2.from_angle(current_overlay.trackPointInfo.angle)
			tangents = [closet_track_tangent, -1 * closet_track_tangent]
	else:
		var centerpoint_and_tangets = draw_wall_and_calculate_centerpoint_and_tangent(mousePosition)
		currentTrackPlacePoint = centerpoint_and_tangets[0]
		tangents = centerpoint_and_tangets[1]
	
	# Need to do an explict null check because snap_tangent could be 0
	if (snap_tangent != null):
		currentPointTangent = snap_tangent
	else:
		determine_tangent_from_switches(tangents)

	if (!trackStartingPosition):
		update_arrow_start()
	
	queue_redraw()


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
	drawableFunctionsToCallLater.append(func(): draw_line(wallStart, wallEnd, highlightColor, 3))
	drawableFunctionsToCallLater.append(func(): draw_circle(currentTrackPlacePoint, 4, highlightColor, false, 4))
	

func draw_wall_and_calculate_centerpoint_and_tangent(mousePos: Vector2):
	var track_position = null 
	var wallToHighlight  = null
	var tileGridPosition = MapManager.getGround().local_to_map(mousePos)
	var tileCenterLocalPosition = MapManager.getGround().map_to_local((tileGridPosition))

	var halfDistance = MapManager.cellSize / 2.0
	var closetWallAndMidpoint = get_closest_wall_and_midpoint(mousePos)	
	wallToHighlight = closetWallAndMidpoint[0];
	track_position = closetWallAndMidpoint[1];

	drawableFunctionsToCallLater.append(func(): draw_line(wallToHighlight[0], wallToHighlight[1],highlightColor, 3))
	drawableFunctionsToCallLater.append(func(): draw_circle(track_position, 4, highlightColor, false, 4))
	var tangents = calculate_tangents(wallToHighlight[0], wallToHighlight[1])

	return [track_position, tangents]
	

func update_arrow_end() -> void:
	arrow_end.visible = true
	# Determine the arrow's tangent point, it's opposite of the track tangent
	var arrowPoint = -1 * currentPointTangent
	# Rotate the arrow sprite to point in the opposite direction of the track's tangent
	rotate_sprite(Vector2.from_angle(trackEndingAngle), arrow_end)
	arrow_end.position = trackEndingPosition - (arrowPoint * (MapManager.cellSize / 2.0))


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
	ending_overlay = current_overlay
	trackEndingAngle = currentPointTangent.angle()

	update_arrow_end()

	var valid = track.compute_track(
		trackStartingPosition, 
		trackStartAngle, 
		trackEndingPosition, 
		trackEndingAngle, 
		minAllowedRadius,
		track_mode_flag,
		curve_type_flag)

	self.validTrack = valid

	if valid:
		track.track_visual_component.modulate = Color8(0, 77, 255, int(0.79 * 255))  # Half-transparent blue
	else:
		track.track_visual_component.modulate = Color(1, 0, 0, 0.5)  # Half-transparent red


func draw_circle_at_point(point: Vector2):
	drawableFunctionsToCallLater.append(func(): draw_circle(point, 3, Color.PINK))
	queue_redraw()
