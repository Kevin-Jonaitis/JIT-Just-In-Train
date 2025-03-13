extends Node3D
class_name TrackBuilder3D


static var track_counter: int = 0  # Initialize the counter


# We need this code, because we need our csg polygon to follow an arbitrary path(not something specified by path3d)
const highlightColor: Color = Color(0, 0, 255, 0.5)
const line_transparency_value: float = 0.3
const line_y_index: int = 1 
var grid_line: Line3D = Line3D.new()
var circle_color: Color = Color(0, 0, 255)
var circle_y_index: int = 2

var grid_circle: MeshInstance3D = MeshInstance3D.new()

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
# var arrow_end : Sprite2D
@onready var arrow_start : Sprite3D = $ArrowStart
@onready var arrow_end : Sprite3D = $ArrowEnd
var track: Track3D

# @onready var track_intersection_searcher: TrackIntersectionSearcher = TrackIntersectionSearcher.new(self)
#TODO: This could be better
@onready var tracks: Tracks = $"../../Tracks"
@onready var trains: Trains = $"../../Trains"
@onready var junctions: Junctions = $"../../Junctions"

var drawableFunctionsToCallLater: Array[Callable] = []

var wall_mesh_instance: MeshInstance3D
var wall_im_mesh: ImmediateMesh
@onready var test_mesh_instance: MeshInstance3D = $TestMesh
@onready var test_mesh_instance_two: MeshInstance3D = $TestMeshTwo
var my_extruded_mesh: ImmediateMesh
var my_extruded_mesh_two: ImmediateMesh
var my_array_mesh: ArrayMesh



# Sharpest turning radius and other constants
# var minAllowedRadius = 45
var minAllowedRadius: float = 10:
	set(value):
		if value < 5:
			return
		if value > 100:
			return
		minAllowedRadius = value
		

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
	my_extruded_mesh_two = ImmediateMesh.new()
	my_array_mesh = ArrayMesh.new()
	# test_mesh_instance = MeshInstance3D.new()
	# test_mesh_instance.mesh = my_extruded_mesh
	test_mesh_instance.mesh = my_array_mesh
	test_mesh_instance_two.mesh = my_extruded_mesh_two

	# Grid line stuff
	grid_line.width = 0.3
	grid_line.name = "HighlightLine"

	grid_circle.mesh = SphereMesh.new()
	grid_circle.scale = Vector3(1, 1, 1)
	grid_circle.name = "HighlightSphere"
	var sphere_material : StandardMaterial3D = StandardMaterial3D.new()
	sphere_material.albedo_color = circle_color
	grid_circle.material_overlay = sphere_material

	add_child(grid_line)
	add_child(grid_circle)
	add_child(test_mesh_instance)
	add_child(wall_mesh_instance)

# Setups a new track(with arrows)
# Should be called after a cancel or solidify of a track, to create a new one
func create_track_node_tree() -> void:
	track = Track3D.new_Track("TempUserTrack" + str(track_counter), curve_type_flag, tracks, false)
	# Need the counter, because (probably) this track is added before the other one is free, so there's a name conflict if we just use tempUserTrack
	
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

func rotate_sprite_3d(unit_tangent: Vector2,sprite: Sprite3D) -> void:
	var angle_2d: float = unit_tangent.angle()
	var y_rotation: float = angle_2d
	# Y needs to be negative so that we're roating around the correct way
	# Honestly, to see why these values are correct, I just played around with the nodes
	# and the values here until it worked. So don't try and reason it too hard. It depends on a 
	# lot of initials(direction sprite is facing, SpriteBase3D.axis)
	sprite.rotation = Vector3(0, -y_rotation + PI, 0)

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
	# TODO: 3D FIX
	# track.track_visual_component.modulate = Color(1,1,1,1)
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

	track.free()
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
	pass

func draw_walls_and_centerpoint(point_position: Vector2, theta: float) -> void:
	# Convert angle to unit vector
	var direction: Vector2 = Vector2.from_angle(theta)
	
	# Calculate perpendicular vector for wall direction
	var perpendicular: Vector2 = Vector2(-direction.y, direction.x)
	
	# Use mouse position directly as center point
	currentTrackPlacePoint = point_position
	
	# Calculate wall endpoints using half cell size
	var halfDistance: float = MapManager3D.cellSize / 2.0
	var wall_start: Vector2 = point_position + (perpendicular * halfDistance)
	var wall_end: Vector2 = point_position - (perpendicular * halfDistance)

	# Draw debug visuals
	TrackDrawer.set_line_attributes(grid_line, [wall_start, wall_end], line_y_index, highlightColor, line_transparency_value)
	grid_circle.position = Vector3(currentTrackPlacePoint.x, Utils.get_y_layer(circle_y_index), currentTrackPlacePoint.y)
	

func draw_wall_and_calculate_centerpoint_and_tangent(mousePos: Vector2) -> Array:
	var wallToHighlight: Array[Vector2] = []
	# var tileGridPosition: Vector2 = MapManager.getGround().local_to_map(mousePos)
	# var _tileCenterLocalPosition: Vector2 = MapManager.getGround().map_to_local((tileGridPosition))

	var _halfDistance: float = MapManager3D.cellSize / 2.0
	var closetWallAndMidpoint: Array = get_closest_wall_and_midpoint(mousePos)	
	wallToHighlight = Array(closetWallAndMidpoint[0] as Array, TYPE_VECTOR2, "", "")
	var track_position: Vector2 = closetWallAndMidpoint[1]

	# Draw debug items
	TrackDrawer.set_line_attributes(grid_line, [wallToHighlight[0], wallToHighlight[1]], line_y_index, highlightColor, line_transparency_value)
	grid_circle.position = Vector3(track_position.x, Utils.get_y_layer(circle_y_index), track_position.y)

	var tangents: Array = calculate_tangents(wallToHighlight[0], wallToHighlight[1])



	return [track_position, tangents]


func update_arrow_end() -> void:
	arrow_end.visible = true
	# Determine the arrow's tangent point, it's opposite of the track tangent
	var arrowPoint: Vector2 = 1 * currentPointTangent
	# Rotate the arrow sprite to point in the opposite direction of the track's tangent
	rotate_sprite_3d(-1 * Vector2.from_angle(trackEndingAngle), arrow_end)
	var vec2 : Vector2 = trackEndingPosition - (arrowPoint * (MapManager3D.cellSize / 2.0))
	arrow_end.position = Utils.convert_to_3d(vec2, 1)


func update_arrow_start() -> void:
	arrow_start.visible = true
	# Determine the arrow's tangent point, it's opposite of the track tangent
	var arrowPoint: Vector2 = 1 * currentPointTangent
	rotate_sprite_3d(-1 * arrowPoint, arrow_start)
	arrow_start.position = Utils.convert_to_3d(currentTrackPlacePoint + (arrowPoint * (MapManager3D.cellSize / 2.0)), 1)
	pass


func round_to_nearest_odd_multiple_of_y(x: float, y: float) -> float:
	var k: float = round((x / y - 1.0) / 2.0)
	return y * (2.0 * k + 1.0)


func get_closest_wall_and_midpoint(mouse_position: Vector2) -> Array:
	var tile_center: Vector2 = Vector2(
		round_to_nearest_odd_multiple_of_y(mouse_position.x, MapManager3D.cellSize / 2.0), 
		round_to_nearest_odd_multiple_of_y(mouse_position.y, MapManager3D.cellSize / 2.0))

	# var tile_center: Vector2 = mouse_position
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

	# TODO: 3D FIX
	# if valid:
	# 	track.track_visual_component.modulate = Color8(0, 77, 255, int(0.79 * 255))  # Half-transparent blue
	# else:
	# 	track.track_visual_component.modulate = Color(1, 0, 0, 0.5)  # Half-transparent red


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
	# var material: StandardMaterial3D = StandardMaterial3D.new()
	# material.albedo_color = Color(1, 1, 1)
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


func test_call() -> void:

	# var my_polygon: Array[Vector2] = [
	# 	Vector2(-0.5, -0.5), #Bottom Left
	# 	Vector2(0.5,-0.5), #Bottom Right
	# 	Vector2(0.5,0.5), #Top Right
	# 	Vector2(-0.5,0.5)] #Top Left

	var my_polygon_cw: Array[Vector2] = [
		Vector2(0.5,0.5), #Top Right
		Vector2(0.5,-0.5), #Bottom Right
		Vector2(-0.5, -0.5), #Bottom Left
		Vector2(-0.5,0.5)] #Top Left
		
	var my_polygon_ccw: Array[Vector2] = [
		Vector2(0.5,0.5), #Top Right
		Vector2(-0.5,0.5), #Top Left
		Vector2(-0.5, -0.5), #Bottom Left
		Vector2(0.5,-0.5)] #Bottom Right
		
		
	
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
	# 	Vector3(4, 0, 2),
	# 	Vector3(4, 0, 3),
	# 	Vector3(5, 0, 4),
	# 	Vector3(6, 0, 5),
	# 	Vector3(6, 0, 6),
	# ]

	var my_path: Array[Vector3] = [
		Vector3(0, 0, 2),
		Vector3(0, 0, 4),
		Vector3(0, 0, 6),
		Vector3(0, 0, 8),
	]



	var my_path_two: Array[Vector3] = [
		Vector3(2, 0, 2),
		Vector3(4, 0, 2),
	]
	
	test_mesh_instance.create_debug_tangents()


	# var material: StandardMaterial3D = StandardMaterial3D.new()
	# material.albedo_color = Color(0,0,255)
	# test_mesh_instance.set_surface_override_material(0, material)

	# TrackDrawer.extrude_polygon_along_path(TrackDrawer.RAIL_POLYGON_VERTICIES, my_path, my_extruded_mesh)

	my_array_mesh.clear_surfaces()
	my_array_mesh.clear_blend_shapes()
	# TrackDrawer.extrude_polygon_along_path_arraymesh(TrackDrawer.RAIL_POLYGON_VERTICIES,
	#  my_path_two, my_array_mesh)

	TrackDrawer.extrude_polygon_along_path_arraymesh(my_polygon_cw, my_path_two, my_array_mesh)

	var rid : RID = my_array_mesh.get_rid()
	var array: Array = my_array_mesh.surface_get_arrays(0)
	var surface: Dictionary = RenderingServer.mesh_get_surface(my_array_mesh.get_rid(), 0)
	var surface1: Dictionary = RenderingServer.mesh_get_surface(my_array_mesh.get_rid(), 0)
	

	# TrackDrawer.extrude_polygon_along_path(TrackDrawer.RAIL_POLYGON_VERTICIES,
	#  my_path_two, my_extruded_mesh_two)

	# TrackDrawer.extrude_polygon_along_path(my_polygon, my_path_two, my_extruded_mesh_two)
