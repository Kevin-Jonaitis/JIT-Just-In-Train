@tool
# A piece of track that Bogie nodes follow along
class_name Track
extends Node2D

var uuid: String = Utils.generate_uuid()
static var counter = 0
@onready var track_visual_component: Node2D = $TrackVisualComponent
## Used to keep track of last changes in the editor, and if changed, to re-render the points
var baked_points_editor_checker : PackedVector2Array = []

@onready var area2d: Area2D = $Area2D
var junction_manager : JunctionManager = JunctionManager.new(self)
var virtual_node_manager : VirtualNodeManager = VirtualNodeManager.new(self)


# Always connected at the index 0 of points
@onready var start_junction: Junction
@onready var end_junction: Junction
# Got to be a better way to do this
@onready var junctions: Junctions = $"../../Junctions"
@onready var trains: Trains = $"../../Trains"
@onready var tracks: Tracks



# Determines if this track has been "placed/solidified" yet or not
var temp = true

const trackPreloaded = preload("res://Scenes/track.tscn")


func _ready():
	checkBeizerCurveInChildren()
	is_ready_called = true

	# If the curve was pre-created in the editor, then we should show the goods
	update_visual_with_bezier_points()

static func new_Track(name_: String, curve_type_flag_: bool, tracks_: Tracks, visible_ = true) -> Track:
	assert(!name_.contains("-"), "This will break pathfinding name parssing if we have a '-' in the name")
	var track: Track = trackPreloaded.instantiate()
	track.name = name_
	track.update_stored_curves(curve_type_flag_)
	track.visible = visible_
	TrackBuilder.track_counter += 1
	track.tracks = tracks_
	tracks_.add_child(track)
	return track


func build_track(starting_overlay: TrackOrJunctionOverlap, ending_overlay: TrackOrJunctionOverlap, optional_name = null):
	if (optional_name):
		assert(!optional_name.contains("-"), "This will break pathfinding name parssing if we have a '-' in the name")
		name = optional_name
	assert(dubins_path && dubins_path.shortest_path, "We haven't defined a path yet!")

	junction_manager.setup_junctions(starting_overlay, ending_overlay)

	virtual_node_manager.setup_interjunction_virtual_nodes()
	area2d.solidify_collision_area()
	temp = false

@export_category("Curve Builder")
@export var edit_curve: bool = false:
	set(value):
		if (!is_ready_called):
			return
		edit_curve = value
		if (edit_curve):
			create_bezier_curve()
		if (!edit_curve):
			cleanup_bezier_curve()
		notify_property_list_changed()

@export var bezier_curve_prop: Curve2D:
	get:
		if (!bezier_curve):
			return
		return bezier_curve.curve
@export var bezier_curve: Path2D
var dubins_path: DubinPath2D

func get_length():
	if (bezier_curve):
		assert(false, "Unimplemented code path!")
	elif (dubins_path):
		return dubins_path.shortest_path.length
	else:
		assert(false, "Unimplemented code path!")
		return 0

func get_points():
	if (bezier_curve):
		assert(false, "Unimplemented code path!")
	elif (dubins_path):
		return dubins_path.shortest_path.get_points()
	else:
		assert(false, "Unimplemented code path!")
		return []

# Would be better to wrap these next two functions
func get_curve():
	if (bezier_curve):
		return bezier_curve.curve
	elif (dubins_path):
		return dubins_path
	else:
		printerr("We haven't defined a curve for this track yet!")
# Returns [point, tangent(in radians)]
func get_point_info_at_index(index: int) -> TrackPointInfo:
	if (bezier_curve):
		assert(false, "Unimplemented code path!")
		return TrackPointInfo.new(self, index, 0)
	elif (dubins_path):
		return get_track_point_info_dubin_path(index)
	else:
		assert(false, "This should be impossible!")
		return TrackPointInfo.new(self, index, 0)


func get_track_point_info_dubin_path(index: int) -> TrackPointInfo:
	# If this is the endpoint for a track. Useful to determine if we should
	# snap the tangent in the opposite direction
	var is_end = false
	var is_start = false
	var points = dubins_path.shortest_path.get_points()
	if index >= points.size():
		assert(false, "This should be impossible!")
		return TrackPointInfo.new(self, index, 0)
	
	var theta = dubins_path.shortest_path.get_angle_at_point_index(index)

	if (is_start || is_end):
		assert(false, "This should be a junction, not a point!")

	return TrackPointInfo.new(self, index, theta)


func get_endpoints_and_directions():
	if (bezier_curve):
		# push_warning("We haven't tested this yet, use at your own peril. The last points in the curve probably arn't the start and end points")
		return []
	elif (dubins_path):	
		if (!dubins_path.shortest_path):
			return []
		return dubins_path.shortest_path.get_endpoints_and_directions()
	else:
		assert(false, "We haven't defined a curve for this track yet!")

func cleanup_bezier_curve() -> void:
	if bezier_curve:
		bezier_curve.queue_free()
		bezier_curve = null


func checkBeizerCurveInChildren():
	for child in get_children():
		if (child.name.begins_with("BezierPath2D")):
			bezier_curve = child
			return

var is_ready_called: bool = false


func create_bezier_curve():
	if (bezier_curve):
		return
	bezier_curve = Path2D.new()
	bezier_curve.curve = Curve2D.new()  # Initialize curve immediately
	var children = get_children() 
	var child_name = children[0].name
	bezier_curve.name = "BezierPath2D_" + str(counter) 
	counter += 1
	add_child(bezier_curve)
	bezier_curve.owner = self.owner

func update_stored_curves(curve_type_flag: bool):
	if (curve_type_flag):
		if (bezier_curve):
			cleanup_bezier_curve()
		if (!dubins_path):
			dubins_path = DubinPath2D.new()
			dubins_path.name = "DubinsPath"
			add_child(dubins_path)
	else:
		if (dubins_path):
			dubins_path.queue_free()
			dubins_path = null
		if (!bezier_curve):
			create_bezier_curve()


func _validate_property(property : Dictionary):
	if property.name == "bezier_curve_prop":
		if (edit_curve):
			property.usage |= PROPERTY_USAGE_EDITOR
		else:
			property.usage &= ~PROPERTY_USAGE_EDITOR

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		update_visual_with_bezier_points()


func update_visual_with_bezier_points():
	if (bezier_curve && bezier_curve.curve && bezier_curve.curve.get_baked_points() != baked_points_editor_checker):
		track_visual_component.update_track_points(bezier_curve.curve.get_baked_points(), 
			bezier_curve.curve.get_baked_length(),
			bezier_curve.curve.sample_baked
			)


# Manually set the track path, rather than computing it
func set_track_path_manual(path: DubinPath):
	dubins_path.paths.append(path)
	dubins_path.shortest_path = path
	update_visual_for_dubin_path()

# Optimize: Get rid of tangets, use just angles everywhere
func compute_track(trackStartingPosition, 
	trackStartAngle: float, 
	trackEndingPosition, 
	trackEndingAngle: float,
	minAllowedRadius, 
	track_mode_flag,
	curve_type_flag,
	draw_paths: bool = true) -> bool:
	var validTrack = false;

	if (curve_type_flag):
		validTrack = dubins_path.calculate_and_draw_paths(trackStartingPosition, 
		trackStartAngle, 
		trackEndingPosition, 
		trackEndingAngle, 
		minAllowedRadius,
		draw_paths)

		# Return early, because there's no track points on an invalid track
		if (!validTrack):
			track_visual_component.make_track_invisible()
			return validTrack

		update_visual_for_dubin_path()

	else:
		# When dealing with bezier curves, the control point for the end of the track will be in the OPPOSITE
		# direction of travel. However here we want the actual direction of travel, so we flip it back.
		var trackEndingDirection = -1 * Vector2.from_angle(trackEndingAngle)
		var curve_result = BezierCurveMath.find_best_curve(
			trackStartingPosition,
			Vector2.from_angle(trackStartAngle),
			trackEndingPosition,
			trackEndingDirection,
			minAllowedRadius,
			track_mode_flag
		)

		# Update track curve with the computed points
		bezier_curve.curve.clear_points()
		bezier_curve.curve.add_point(curve_result.start_position, Vector2.ZERO, curve_result.start_control_point)
		bezier_curve.curve.add_point(curve_result.end_position, curve_result.end_control_point)

		validTrack = curve_result.validTrack
		update_visual_with_bezier_points()
	
	return validTrack

func update_visual_for_dubin_path():
	track_visual_component.update_track_points(dubins_path.shortest_path.get_points(), 
	dubins_path.shortest_path.length,
	dubins_path.shortest_path.get_point_at_offset,
	Vector2.from_angle(dubins_path.shortest_path.start_theta),
	Vector2.from_angle(dubins_path.shortest_path.end_theta)
	)


func get_angle_at_point_index(index: int) -> float:
	if (bezier_curve):
		assert(false, "Unimplemented code path!")
		return -1
	elif (dubins_path):
		return dubins_path.shortest_path.get_angle_at_point_index(index)
	else:
		assert(false, "We haven't defined a curve for this track yet!")
		return 0

func delete_track():
	start_junction.remove_track_and_nodes(self)
	end_junction.remove_track_and_nodes(self)
	virtual_node_manager.delete_interjunction_virtual_nodes()
	self.queue_free()

func get_distance_to_point(point_index: int) -> float:
	if (bezier_curve):
		assert(false, "Unimplemented code path!")
		return 0
	elif (dubins_path):
		return dubins_path.shortest_path.get_distance_to_point(point_index)
	else:
		assert(false, "We haven't defined a curve for this track yet!")
		return 0


func length():
	if (bezier_curve):
		assert(false, "Unimplemented code path!")
	elif (dubins_path):
		return dubins_path.shortest_path.length
	else:
		assert(false, "We haven't defined a curve for this track yet!")
		return 0

func add_temp_virtual_nodes(point_index: int, train: Train) -> Array[VirtualNode]:
	return virtual_node_manager.add_temp_virtual_nodes(point_index, train)

func remove_temp_virtual_node(point_index: int, train: Train):
	virtual_node_manager.remove_temp_virtual_node(point_index, train)

func get_point_at_index(index: int) -> Vector2:
	if (dubins_path):
		return dubins_path.shortest_path.get_point_at_index(index)
	else:
		assert(false, "We haven't defined a curve for this track yet, or you're using a curve type we haven't implemented!!")
		return Vector2.ZERO
