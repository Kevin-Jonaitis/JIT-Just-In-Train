extends Node3D
class_name TrackBuilder3D


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
#Whether it's valid to place a track start/end point here(for example, due to a stop you can't)
var can_place_point: bool = false

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

# @onready var track_intersection_searcher: TrackIntersectionSearcher = TrackIntersectionSearcher.new(self)
#TODO: This could be better
@onready var tracks: Tracks = $"../../Tracks"
@onready var trains: Trains = $"../../Trains"
@onready var junctions: Junctions = $"../../Junctions"

var drawableFunctionsToCallLater: Array[Callable] = []

var wall_mesh_instance: MeshInstance3D
var wall_im_mesh: ImmediateMesh
var test_mesh_instance: MeshInstance3D
var my_extruded_mesh: ImmediateMesh


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


	# Mesh stuff:
	# Create a MeshInstance3D node
	wall_mesh_instance = MeshInstance3D.new()
	# Create the ImmediateMesh resource
	wall_im_mesh = ImmediateMesh.new()
	# Assign the ImmediateMesh to the MeshInstance3D's mesh property
	# Add the MeshInstance3D as a child so it is drawn in the scene
	wall_mesh_instance.mesh = wall_im_mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1,1,1)  # Use the color parameter from your function
	#wall_mesh_instance.set_surface_override_material(0, material)
	my_extruded_mesh = ImmediateMesh.new()
	test_mesh_instance = MeshInstance3D.new()
	test_mesh_instance.mesh = my_extruded_mesh
	add_child(test_mesh_instance)

	add_child(wall_mesh_instance)

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
	
func find_nearest_grid_and_tangents(mousePos: OptionalVector2) -> void:
	if mousePos == null:
		return
	var mousePosition: Vector2 = mousePos.value
	
	

	# current_overlay = track_intersection_searcher.check_for_junctions_or_track_at_position(mousePosition)
	var near_stop: bool = TrackIntersectionSearcher.check_for_stops_at_position(current_overlay)
	if (near_stop):
		can_place_point = false
		arrow_start.modulate = Color(1, 0, 0)
		arrow_end.modulate = Color(1, 0, 0)
	else:
		# Reset every time we run to find the nearest grid point
		can_place_point = true
		arrow_start.modulate = Color(1, 1, 1)
		arrow_end.modulate = Color(1, 1, 1)
		
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
	
	# queue_redraw()


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
	var halfDistance: float = MapManager3D.cellSize / 2.0
	var wallStart: Vector2 = point_position + (perpendicular * halfDistance)
	var wallEnd: Vector2 = point_position - (perpendicular * halfDistance)

	# draw_line_mesh(wall_im_mesh, [Vector2(0,0), Vector2(0,5), Vector2(5,5)])
	# Draw debug visuals
	# drawableFunctionsToCallLater.append(func() -> void: draw_line(wallStart, wallEnd, highlightColor, 3))
	# drawableFunctionsToCallLater.append(func() -> void: draw_circle(currentTrackPlacePoint, 4, highlightColor, false, 4))
	

func draw_wall_and_calculate_centerpoint_and_tangent(mousePos: Vector2) -> Array:
	var track_position: Variant = null 
	var wallToHighlight: Array[Vector2] = []
	# var tileGridPosition: Vector2 = MapManager.getGround().local_to_map(mousePos)
	# var _tileCenterLocalPosition: Vector2 = MapManager.getGround().map_to_local((tileGridPosition))

	var _halfDistance: float = MapManager3D.cellSize / 2.0
	var closetWallAndMidpoint: Array = get_closest_wall_and_midpoint(mousePos)	
	wallToHighlight = Array(closetWallAndMidpoint[0] as Array, TYPE_VECTOR2, "", "")
	track_position = closetWallAndMidpoint[1];


	# drawableFunctionsToCallLater.append(func() -> void: draw_line(wallToHighlight[0], wallToHighlight[1], highlightColor, 3))
	# drawableFunctionsToCallLater.append(func() -> void: draw_circle(track_position as Vector2, 4, highlightColor, false, 4))
	var tangents: Array = calculate_tangents(wallToHighlight[0], wallToHighlight[1])

	return [track_position, tangents]
	

func update_arrow_end() -> void:
	arrow_end.visible = true
	# Determine the arrow's tangent point, it's opposite of the track tangent
	var arrowPoint: Vector2 = -1 * currentPointTangent
	# Rotate the arrow sprite to point in the opposite direction of the track's tangent
	rotate_sprite(Vector2.from_angle(trackEndingAngle), arrow_end)
	arrow_end.position = trackEndingPosition - (arrowPoint * (MapManager3D.cellSize / 2.0))


func update_arrow_start() -> void:
	arrow_start.visible = true
	# Determine the arrow's tangent point, it's opposite of the track tangent
	var arrowPoint: Vector2 = -1 * currentPointTangent
	rotate_sprite(-1 * arrowPoint, arrow_start)
	arrow_start.position = currentTrackPlacePoint + (arrowPoint * (MapManager3D.cellSize / 2.0))


func get_closest_wall_and_midpoint(mouse_position: Vector2) -> Array:
	# var tileGridPosition: Vector2 = MapManager3D.getGround().local_to_map(mouse_position)
	# var tile_center: Vector2 = MapManager3D.getGround().map_to_local(tileGridPosition)
	var tile_center: Vector2 = mouse_position
	var half_distance: float = MapManager3D.cellSize / 2.0
	
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


# func draw_circle_at_point(point: Vector2) -> void:
# 	drawableFunctionsToCallLater.append(func() -> void: draw_circle(point, 3, Color.PINK))
# 	queue_redraw()

class QuadValues:
	var s_top_right: Vector3
	var s_top_left: Vector3
	var s_bottom_right: Vector3
	var s_bottom_left: Vector3
	var e_top_right: Vector3
	var e_top_left: Vector3
	var e_bottom_right: Vector3
	var e_bottom_left: Vector3

	func _init(a: Vector3, b: Vector3, width: float) -> void:
		var half: float = width / 2.0
		# Define quad vertices for cross-section at point a.
		s_top_right = a + Vector3( half, half,  half)
		s_top_left = a + Vector3(-half, half,  half)
		s_bottom_right = a + Vector3( half, -half, half)
		s_bottom_left = a + Vector3(-half, -half, half)

		# Define quad vertices for cross-section at point b.
		e_top_right = b + Vector3( half, half,  half)
		e_top_left = b + Vector3(-half, half,  half)
		e_bottom_right = b + Vector3( half, -half, half)
		e_bottom_left = b + Vector3(-half, -half, half)




func draw_line_mesh(mesh: ImmediateMesh, points: Array[Vector2], height_from_bottom : float = 10, width: float = 0.3) -> void:
	# var height_from_bottom: float = 10
	var start_point: Vector2 = points[0]
	var end_point: Vector2 = points[-1]

	# USE clockwise winding orders
	OptionalVector2.print(Utils.get_ground_mouse_position_vec2())
	var start_v3: Vector3 = Vector3(start_point.x, height_from_bottom, start_point.y)
	var end_v3: Vector3 = Vector3(end_point.x, height_from_bottom, end_point.y)

	var quad_values: QuadValues = QuadValues.new(start_v3, end_v3, width)

	# These are in the XZ plane; y is unchanged.
	
	# TOP RIGHT, TOP LEFT, BOTTOM RIGHT, BOTTOM LEFT
	var s_top_right: Vector3 = quad_values.s_top_right
	var s_top_left: Vector3 = quad_values.s_top_left
	var s_bottom_right: Vector3 = quad_values.s_bottom_right
	var s_bottom_left: Vector3 = quad_values.s_bottom_left
	var e_top_right: Vector3 = quad_values.e_top_right
	var e_top_left: Vector3 = quad_values.e_top_left
	var e_bottom_right: Vector3 = quad_values.e_bottom_right
	var e_bottom_left: Vector3 = quad_values.e_bottom_left

	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)

	# --- Draw quad at point a (two triangles) ---
	# Triangle 1: a_v1, a_v2, a_v3.
	mesh.surface_add_vertex(s_top_right)
	mesh.surface_add_vertex(s_top_left)
	mesh.surface_add_vertex(s_bottom_right)
	# Triangle 2: a_v2, a_v4, a_v3.
	mesh.surface_add_vertex(s_top_left)
	mesh.surface_add_vertex(s_bottom_left)
	mesh.surface_add_vertex(s_bottom_right)

	for i: int in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var quad_values_internal: QuadValues = QuadValues.new(
			Vector3(a.x, height_from_bottom, a.y), Vector3(b.x, height_from_bottom, b.y), width)
		connect_two_points_internal(mesh, quad_values_internal)

	# connect_two_points_internal(mesh, quad_values, height_from_bottom)


	#Connect end
	mesh.surface_add_vertex(e_top_left)
	mesh.surface_add_vertex(e_top_right)
	mesh.surface_add_vertex(e_bottom_right)

	mesh.surface_add_vertex(e_top_left)
	mesh.surface_add_vertex(e_bottom_right)
	mesh.surface_add_vertex(e_bottom_left)
	

	mesh.surface_end()


func connect_two_points_internal(mesh: ImmediateMesh, quad_values: QuadValues) -> void:
	var s_top_right: Vector3 = quad_values.s_top_right
	var s_top_left: Vector3 = quad_values.s_top_left
	var s_bottom_right: Vector3 = quad_values.s_bottom_right
	var s_bottom_left: Vector3 = quad_values.s_bottom_left
	var e_top_right: Vector3 = quad_values.e_top_right
	var e_top_left: Vector3 = quad_values.e_top_left
	var e_bottom_right: Vector3 = quad_values.e_bottom_right
	var e_bottom_left: Vector3 = quad_values.e_bottom_left


	# Connect top
	mesh.surface_add_vertex(s_top_left)
	mesh.surface_add_vertex(s_top_right)
	mesh.surface_add_vertex(e_top_right)

	#Connect top
	mesh.surface_add_vertex(e_top_right)
	mesh.surface_add_vertex(e_top_left)
	mesh.surface_add_vertex(s_top_left)

	# Connect left
	mesh.surface_add_vertex(s_top_right)
	mesh.surface_add_vertex(s_bottom_right)
	mesh.surface_add_vertex(e_bottom_right)

	# Connect left
	mesh.surface_add_vertex(e_bottom_right)
	mesh.surface_add_vertex(e_top_right)
	mesh.surface_add_vertex(s_top_right)

	# Connect right
	mesh.surface_add_vertex(s_bottom_left)
	mesh.surface_add_vertex(s_top_left)
	mesh.surface_add_vertex(e_top_left)

	mesh.surface_add_vertex(e_top_left)
	mesh.surface_add_vertex(e_bottom_left)
	mesh.surface_add_vertex(s_bottom_left)

	# Connect bottom
	mesh.surface_add_vertex(s_bottom_right)
	mesh.surface_add_vertex(s_bottom_left)
	mesh.surface_add_vertex(e_bottom_left)

	mesh.surface_add_vertex(e_bottom_left)
	mesh.surface_add_vertex(e_bottom_right)
	mesh.surface_add_vertex(s_bottom_right)


# extrude_along_path.gd
# GDScript 4.x style with explicit typing.

func test_call() -> void:

	var my_polygon: Array[Vector2] = [
		Vector2(-0.5, -0.5), #Bottom Left
		Vector2(0.5,-0.5), #Bottom Right
		Vector2(0.5,0.5), #Top Right
		Vector2(-0.5,0.5)] #Top Left
	
	# # Hexagon
	# var my_polygon: Array[Vector2] = [
	# 	Vector2(1.0, 0.0),
	# 	Vector2(0.5, 0.86602540378),
	# 	Vector2(-0.5, 0.86602540378),
	# 	Vector2(-1.0, 0.0),
	# 	Vector2(-0.5, -0.86602540378),
	# 	Vector2(0.5, -0.86602540378)
	# ]

	# var my_path: Array[Vector3] = [
	# 	Vector3(0, 0, 2),
	# 	Vector3(0, 0, 3),
	# 	Vector3(0, 0, 4),
	# 	Vector3(4, 0, 4),
	# 	Vector3(8, 0, 4),
	# 	Vector3(10, 0, 4),
	# 	Vector3(10, 0, 4),
	# 	# Vector3(1, 0, 3),
	# 	# Vector3(1.5, 0, 3.5)
	# 	# Vector3(8, 0, 12)
	# ]

	var my_path: Array[Vector3] = [
		Vector3(0, 0, 2),
		Vector3(0, 0, 3),
		Vector3(1, 0, 4),
		Vector3(2, 0, 5),
		Vector3(2, 0, 6),
	]


	extrude_polygon_along_path(my_polygon, my_path, my_extruded_mesh)



func extrude_polygon_along_path(
	polygon_2d: Array[Vector2],
	path_points: Array[Vector3],
	immediate_mesh: ImmediateMesh
) -> void:
	# var immediate_mesh: ImmediateMesh = ImmediateMesh.new()

	# Early exit if invalid input
	if polygon_2d.is_empty() or path_points.size() < 2:
		return

	# 1) Triangulate the polygon if you want to make end caps
	var polygon_indices: PackedInt32Array = Geometry2D.triangulate_polygon(polygon_2d)

	# 2) Create a Transform3D array for each segment of the path
	var transforms: Array[Transform3D] = []

	var points_count: int = path_points.size()
	for i: int in range(points_count):
		if (i == 0):
			var transform: Transform3D = Transform3D()			
			transform = transform.looking_at(path_points[i + 1], Vector3.UP)
			transform = transform.translated(path_points[i])
			transforms.append(transform)
		elif i < points_count - 1:
			# var origin: Vector3 = path_points[i]
			# var next_pt: Vector3 = path_points[i + 1]
			# var transform: Transform3D = Transform3D()
			# transform.origin = origin
			# transform = transform.looking_at(next_pt, Vector3.UP)
			# transforms.append(transform)


			# var origin: Vector3 = path_points[i - 1]
			# var next_pt: Vector3 = path_points[i + 1]
			# var direction: Vector3 = (next_pt - origin).normalized()

			var prev_dir: Vector3 = (path_points[i] - path_points[i - 1]).normalized()
			var next_dir: Vector3 = (path_points[i + 1] - path_points[i]).normalized()
			var direction: Vector3 = (prev_dir + next_dir).normalized()

			# # Compute a right vector and use UP (Y axis) as reference.
			# var right: Vector3 = Vector3.UP.cross(forward).normalized()
			# var up: Vector3 = forward.cross(right).normalized()
			# # Build a basis so that the -z axis points along our forward direction.
			# var basis: Basis = Basis(right, up, -forward)
			# var transform: Transform3D = Transform3D(basis, origin)

			# var looking_at: Transform2D = Transform3D().looking_at(path_points[i + 1], Vector3.UP);
			var transform: Transform3D = Transform3D()			
			transform = transform.looking_at(direction, Vector3.UP)
			transform = transform.translated(path_points[i])
			transforms.append(transform)
		elif(i == points_count - 1):
			# For the last point, reuse orientation from the previous or just identity
			var direction: Vector3 = (path_points[i] - path_points[i - 1]).normalized()
			var last_transform: Transform3D = Transform3D()
			last_transform.basis = transforms[-1].basis		# Copy the same basis
			last_transform = last_transform.looking_at(direction, Vector3.UP)
			last_transform = last_transform.translated(path_points[i])
			# var next_pt: Vector3 = path_points[i + 1]
			# var last_transform: Transform3D = transforms[transforms.size() - 1] if transforms.size() > 0 else Transform3D()
			transforms.append(last_transform) 
		else:
			assert(false, "We should never get here")

	# 3) Build side walls between consecutive rings
	immediate_mesh.clear_surfaces()
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)

	var prev_global_points: Array[Vector3] = []
	var current_global_points: Array[Vector3] = []
	print("STARTING EXTRUSION")
	print(" ")
	for i: int in range(transforms.size()):
		current_global_points.clear()

		var t: Transform3D = transforms[i]
		# Convert each 2D vertex to 3D for this ring
		for v2: Vector2 in polygon_2d:
			var v3: Vector3 = Vector3(v2.x, v2.y, 0.0) # WE ASSUME THE POLYGON IS 2D and "UPRIGHT" on the X AXIS
			current_global_points.append(t * v3)

		print("CURRENT GLOBAL POINTS:")
		print(current_global_points)

		# If we have a previous ring, connect them with quads -> triangles
		# print("NEW:")
		if i > 0:
			var ring_size: int = polygon_2d.size()
			for j: int in range(ring_size):
				var j_next: int = (j + 1) % ring_size

				var vA: Vector3 = prev_global_points[j]
				var vB: Vector3 = prev_global_points[j_next]
				var vC: Vector3 = current_global_points[j_next]
				var vD: Vector3 = current_global_points[j]
				# print("va:", vA)
				# print("vb:", vB)
				# print("vc:", vC)
				# print("vd:", vD)

				# Tri 1
				
				
				# immediate_mesh.surface_add_vertex(vC)
				# immediate_mesh.surface_add_vertex(vB)
				# immediate_mesh.surface_add_vertex(vA)

				immediate_mesh.surface_add_vertex(vA)
				immediate_mesh.surface_add_vertex(vB)
				immediate_mesh.surface_add_vertex(vC)

				# print("TRIANGLE:", vA, vB, vC)

				# Tri 2
				immediate_mesh.surface_add_vertex(vC)
				immediate_mesh.surface_add_vertex(vD)
				immediate_mesh.surface_add_vertex(vA)

				# immediate_mesh.surface_add_vertex(vA)
				# immediate_mesh.surface_add_vertex(vD)
				# immediate_mesh.surface_add_vertex(vC)
				

				# print("TRIANGLE:", vC, vD, vA)

		# Prepare for next iteration
		prev_global_points = current_global_points.duplicate(true)

	immediate_mesh.surface_end()

	# 4) (Optional) Add end caps here using polygon_indices for the first and/or last transform.
	# Front cap (at the beginning)
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var front_transform: Transform3D = transforms[0]
	var front_vertices: Array[Vector3] = []
	for v2: Vector2 in polygon_2d:
		var v3: Vector3 = Vector3(v2.x, v2.y, 0.0)
		front_vertices.append(front_transform * v3)
	# Use the triangulation data from polygon_indices.
	for i: int  in range(0, polygon_indices.size(), 3):
		var idx0: int = polygon_indices[i]
		var idx1: int = polygon_indices[i + 1]
		var idx2: int = polygon_indices[i + 2]
		immediate_mesh.surface_add_vertex(front_vertices[idx2])
		immediate_mesh.surface_add_vertex(front_vertices[idx1])
		immediate_mesh.surface_add_vertex(front_vertices[idx0])
	immediate_mesh.surface_end()

	# Back cap (at the end)
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var back_transform: Transform3D = transforms[transforms.size() - 1]
	var back_vertices: Array[Vector3] = []
	for v2: Vector2 in polygon_2d:
		var v3: Vector3 = Vector3(v2.x, v2.y, 0.0)
		back_vertices.append(back_transform * v3)
	# Reverse the triangle winding so that the normal points outward.
	for i: int in range(0, polygon_indices.size(), 3):
		var idx0: int = polygon_indices[i]
		var idx1: int = polygon_indices[i + 1]
		var idx2: int = polygon_indices[i + 2]
		immediate_mesh.surface_add_vertex(back_vertices[idx0])
		immediate_mesh.surface_add_vertex(back_vertices[idx1])
		immediate_mesh.surface_add_vertex(back_vertices[idx2])
		
	immediate_mesh.surface_end()
