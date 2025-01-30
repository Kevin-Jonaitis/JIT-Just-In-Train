extends Node2D
class_name TrackBuilder


static var track_counter: int = 0  # Initialize the counter


var highlightColor: Color = Color(0, 0, 255, 0.5)
var circleColor: Color = Color(0, 0, 255)

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

var trackStartingPosition: Variant = null
var starting_overlay: TrackOrJunctionOverlap # nullable
var trackEndingPosition: Variant = null
var ending_overlay: TrackOrJunctionOverlap # nullable
var trackStartAngle: float = 0
var trackEndingAngle: float = 0
# If it's possible to build the track given the starting and ending positions and directions
var validTrack: bool = false

## Track Settings
var tangentSwitchEndpoint: bool = false
var tangentSwitchStartpoint: bool = false

# If we are currently sticking to a starting track for the direction
# Vector2 or null
var closet_track_tangent: Variant = null
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
@onready var junctions: Junctions = $"../../Junctions"

var drawableFunctionsToCallLater: Array[Callable] = []


# Sharpest turning radius and other constants
# var minAllowedRadius = 45
var minAllowedRadius: float = 100:
	set(value):
		if value < 15:
			return
		if value > 1000:
			return
		minAllowedRadius = value
		
var ratio_distance_to_baked_points: float = 5.0

func _draw() -> void:
	for function: Callable in drawableFunctionsToCallLater:
		function.call()
	drawableFunctionsToCallLater.clear()

# Preloaded assets
const trackPreloaded: PackedScene = preload("res://Scenes/track.tscn")
const track_direction_arrow: Texture2D = preload("res://Assets/arrow_single.png")
const scene: PackedScene = preload("res://Scenes/track_builder.tscn")



var curve_type_flag: bool = true:
	set(value):
		curve_type_flag = value
		if (is_instance_valid(track)):
			track.update_stored_curves(curve_type_flag)


func _ready() -> void:
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
func create_track_node_tree() -> void:
	track = Track.new_Track("TempUserTrack" + str(track_counter), curve_type_flag, tracks, false)
	# Need the counter, because (probably) this track is added before the other one is free, so there's a name conflict if we just use tempUserTrack
	
	add_child(arrow_start)
	add_child(arrow_end)
	arrow_start.visible = false
	arrow_end.visible = false

func flip_track_direction() -> void:
	if (!trackEndingPosition):
		tangentSwitchStartpoint = !tangentSwitchStartpoint
	elif  (trackStartingPosition && trackEndingPosition):
		tangentSwitchEndpoint = !tangentSwitchEndpoint
	else:
		push_error("Invalid state, we shouldn't have both a start and end position and flipping the track")

# Calculate the unit tangents
func calculate_tangents(point_a: Vector2, point_b: Vector2) -> Array[Vector2]:
	# Direction vector
	var direction: Vector2 = point_b - point_a

	# Left and right normals
	var left_normal: Vector2 = Vector2(-direction.y, direction.x).normalized()
	var right_normal: Vector2 = Vector2(direction.y, -direction.x).normalized()

	return [
		left_normal,
		right_normal
	]


func rotate_sprite(unit_tangent: Vector2, sprite: Sprite2D) -> void:
	sprite.rotation = unit_tangent.angle()


func intialize_and_set_start_point() -> void:
	trackStartingPosition = currentTrackPlacePoint
	starting_overlay = current_overlay
	trackStartAngle = currentPointTangent.angle()
	track.visible = true	


func solidifyTrack() -> void:
	track.build_track(starting_overlay, ending_overlay, "UserPlacedTrack_" + str(track_counter))

	reset_track_builder()
	create_track_node_tree()
	trains.update_schedules()

# We want to reset most things, but leave things like
# arrow direction and track type intack for next track placement
func reset_track_builder() -> void:
	if (track.dubins_path):
		track.dubins_path.clear_drawables()
	remove_child(arrow_start)
	remove_child(arrow_end)
	track.track_visual_component.modulate = Color(1,1,1,1)
	trackStartingPosition = null
	trackEndingPosition = null
	starting_overlay = null
	ending_overlay = null
	trackStartAngle = 0
	trackEndingAngle = 0


func cancel_track() -> void:
	if (!is_instance_valid(track)):
		return
	reset_track_builder()

	track.queue_free()
	track = null	

	create_track_node_tree()
	
func find_nearest_grid_and_tangents(mousePos: Vector2) -> void:
	var mousePosition: Vector2 = mousePos
	current_overlay = track_intersection_searcher.check_for_junctions_or_track_at_position(mousePosition)
	var snap_tangent: Variant = null
	var tangents: Array = []
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
		var centerpoint_and_tangets: Array = draw_wall_and_calculate_centerpoint_and_tangent(mousePosition)
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


func determine_tangent_from_switches(tangents: Array) -> void:
	if (!trackStartingPosition):
		currentPointTangent = tangents[0] if tangentSwitchStartpoint else tangents[1]
	elif(trackStartingPosition && trackEndingPosition):
		currentPointTangent = tangents[0] if tangentSwitchEndpoint else tangents[1]
	else:
		printerr("Unknown state, tracking starting position and track ending position both set")

func draw_walls_and_centerpoint(point_position: Vector2, theta: float) -> void:
	# Convert angle to unit vector
	var direction: Vector2 = Vector2.from_angle(theta)
	
	# Calculate perpendicular vector for wall direction
	var perpendicular: Vector2 = Vector2(-direction.y, direction.x)
	
	# Use mouse position directly as center point
	currentTrackPlacePoint = point_position
	
	# Calculate wall endpoints using half cell size
	var halfDistance: float = MapManager.cellSize / 2.0
	var wallStart: Vector2 = point_position + (perpendicular * halfDistance)
	var wallEnd: Vector2 = point_position - (perpendicular * halfDistance)
	
	# Draw debug visuals
	drawableFunctionsToCallLater.append(func() -> void: draw_line(wallStart, wallEnd, highlightColor, 3))
	drawableFunctionsToCallLater.append(func() -> void: draw_circle(currentTrackPlacePoint, 4, highlightColor, false, 4))
	

func draw_wall_and_calculate_centerpoint_and_tangent(mousePos: Vector2) -> Array:
	var track_position: Variant = null 
	var wallToHighlight: Array[Vector2] = []
	var tileGridPosition: Vector2 = MapManager.getGround().local_to_map(mousePos)
	var _tileCenterLocalPosition: Vector2 = MapManager.getGround().map_to_local((tileGridPosition))

	var _halfDistance: float = MapManager.cellSize / 2.0
	var closetWallAndMidpoint: Array = get_closest_wall_and_midpoint(mousePos)	
	wallToHighlight = Array(closetWallAndMidpoint[0] as Array, TYPE_VECTOR2, "", "")
	track_position = closetWallAndMidpoint[1];

	drawableFunctionsToCallLater.append(func() -> void: draw_line(wallToHighlight[0], wallToHighlight[1], highlightColor, 3))
	drawableFunctionsToCallLater.append(func() -> void: draw_circle(track_position as Vector2, 4, highlightColor, false, 4))
	var tangents: Array = calculate_tangents(wallToHighlight[0], wallToHighlight[1])

	return [track_position, tangents]
	

func update_arrow_end() -> void:
	arrow_end.visible = true
	# Determine the arrow's tangent point, it's opposite of the track tangent
	var arrowPoint: Vector2 = -1 * currentPointTangent
	# Rotate the arrow sprite to point in the opposite direction of the track's tangent
	rotate_sprite(Vector2.from_angle(trackEndingAngle), arrow_end)
	arrow_end.position = trackEndingPosition - (arrowPoint * (MapManager.cellSize / 2.0))


func update_arrow_start() -> void:
	arrow_start.visible = true
	# Determine the arrow's tangent point, it's opposite of the track tangent
	var arrowPoint: Vector2 = -1 * currentPointTangent
	rotate_sprite(-1 * arrowPoint, arrow_start)
	arrow_start.position = currentTrackPlacePoint + (arrowPoint * (MapManager.cellSize / 2.0))


func get_closest_wall_and_midpoint(mouse_position: Vector2) -> Array:
	var tileGridPosition: Vector2 = MapManager.getGround().local_to_map(mouse_position)
	var tile_center: Vector2 = MapManager.getGround().map_to_local(tileGridPosition)
	var half_distance: float = MapManager.cellSize / 2.0
	
	# Define the wall edges as start and end points
	var walls: Array = [
		[tile_center + Vector2(-half_distance, -half_distance), tile_center + Vector2(-half_distance, half_distance)],   # Left wall
		[tile_center + Vector2(half_distance, -half_distance), tile_center + Vector2(half_distance, half_distance)],    # Right wall
		[tile_center + Vector2(-half_distance, -half_distance), tile_center + Vector2(half_distance, -half_distance)],  # Top wall
		[tile_center + Vector2(-half_distance, half_distance), tile_center + Vector2(half_distance, half_distance)]     # Bottom wall
	]

	# Find the closest wall manually
	var closest_wall: Array = []
	var smallest_distance: float = INF
	var closest_midpoint: Vector2 = Vector2.ZERO
	for wall: Array in walls:
		var wall_midpoint: Vector2 = (wall[0] + wall[1]) / 2.0
		var distance: float = wall_midpoint.distance_to(mouse_position)
		if distance < smallest_distance:
			smallest_distance = distance
			closest_wall = wall
			closest_midpoint = wall_midpoint

	return [closest_wall, closest_midpoint]


func compute_path() -> void:
	# Update ending position
	trackEndingPosition = currentTrackPlacePoint
	ending_overlay = current_overlay
	trackEndingAngle = currentPointTangent.angle()

	update_arrow_end()

	var valid: bool = track.compute_track(
		trackStartingPosition as Vector2, 
		trackStartAngle, 
		trackEndingPosition as Vector2, 
		trackEndingAngle, 
		minAllowedRadius,
		track_mode_flag,
		curve_type_flag)

	self.validTrack = valid

	if valid:
		track.track_visual_component.modulate = Color8(0, 77, 255, int(0.79 * 255))  # Half-transparent blue
	else:
		track.track_visual_component.modulate = Color(1, 0, 0, 0.5)  # Half-transparent red


func draw_circle_at_point(point: Vector2) -> void:
	drawableFunctionsToCallLater.append(func() -> void: draw_circle(point, 3, Color.PINK))
	queue_redraw()
