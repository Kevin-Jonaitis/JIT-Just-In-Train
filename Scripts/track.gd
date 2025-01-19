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

# Got to be a better way to do this
@onready var start_junction: Junction
@onready var end_junction: Junction
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
		name = optional_name
	assert(dubins_path && dubins_path.shortest_path, "We haven't defined a path yet!")

	setup_junctions(starting_overlay, ending_overlay)
	
	assert(start_junction && end_junction, "We should have junctions by now! Can't construct pathfinding nodes without them")
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
	var current = points[index]
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
	start_junction.remove_track(self)
	end_junction.remove_track(self)
	self.queue_free()


# Create a track with the following juctions. If the start or end overlaps an existing track, split that track up into 2 tracks,
# and create those new tracks with the new junctions as well
func setup_junctions(starting_overlay: TrackOrJunctionOverlap, ending_overlay: TrackOrJunctionOverlap):
	if (bezier_curve):
		assert(false, "We haven't implemented junctions for bezier curves yet")
	elif (dubins_path):
		create_dubin_junctions(starting_overlay, ending_overlay)
	else:
		assert(false, "We should never get here")

func create_dubin_junctions(starting_overlay: TrackOrJunctionOverlap, ending_overlay: TrackOrJunctionOverlap):
	var startingJunction;
	if (starting_overlay):
		handle_track_joining_dubin(starting_overlay, true)
	else:
		var first_point = dubins_path.shortest_path._points[0]
		startingJunction = Junction.new_Junction(first_point, junctions, \
	Junction.NewConnection.new(self, true))
	
	# Check if our ending point overlaps our just-placed starting junction
	if (startingJunction):
		var point_to_check
		if (ending_overlay && ending_overlay.trackPointInfo):
			point_to_check = ending_overlay.trackPointInfo.get_point()
		if (!ending_overlay):
			point_to_check = dubins_path.shortest_path._points[-1]
		if (point_to_check && \
		is_junction_within_search_radius(startingJunction, point_to_check)):
			startingJunction.add_connection(Junction.NewConnection.new(self, false))
			return

	if (ending_overlay):
		handle_track_joining_dubin(ending_overlay, false)
	else:
		var last_point = dubins_path.shortest_path._points[-1]
		Junction.new_Junction(last_point, junctions, \
		Junction.NewConnection.new(self, false)) 


func is_junction_within_search_radius(junction_one: Junction, point: Vector2) -> bool:
	if (point.distance_to(junction_one.position) <= TrackIntersectionSearcher.SEARCH_RADIUS):
		return true
	else:
		return false

func handle_track_joining_dubin(overlap: TrackOrJunctionOverlap, is_start_of_new_track: bool):
	if (overlap.junction):
		overlap.junction.add_connection(Junction.NewConnection.new(self, is_start_of_new_track))
	elif (overlap.trackPointInfo):
		var middle_junction = split_track_at_point(overlap.trackPointInfo)
		middle_junction.add_connection(Junction.NewConnection.new(self, is_start_of_new_track))
	else:
		assert(false, "We should never get here, we should always have a junction or track point info if we're in this function")

func split_track_at_point(trackPointInfo: TrackPointInfo) -> Junction:	
	var split_tracks: Array[Track] = create_split_track(trackPointInfo)
	var first_half = split_tracks[0]
	var second_half = split_tracks[1]
	trains.update_train_stops(trackPointInfo.track, first_half, second_half)
	trackPointInfo.track.delete_track()
	return split_tracks[0].end_junction

func create_split_track(trackPointInfo: TrackPointInfo) -> Array[Track]:
	if (!trackPointInfo.track.dubins_path):
		assert(false, "We haven't implemented split for any other type of path")
		return []
	var new_tracks : Array[Track] = []
	var new_dubins_paths : Array[DubinPath] = trackPointInfo.track.dubins_path.shortest_path.split_at_point_index(trackPointInfo.point_index)
	var middleJunction: Junction
	var curve_type_flag = true if dubins_path else false
	for i in range(new_dubins_paths.size()):
		var newTrack = Track.new_Track("SplitTrack-" + str(TrackBuilder.track_counter), curve_type_flag, tracks)
		newTrack.set_track_path_manual(new_dubins_paths[i])

		if (i == 0):
			newTrack.build_track(TrackOrJunctionOverlap.new(trackPointInfo.track.start_junction, null), null)
			middleJunction = newTrack.end_junction
		elif (i == 1):
			newTrack.build_track(TrackOrJunctionOverlap.new(middleJunction, null), TrackOrJunctionOverlap.new(trackPointInfo.track.end_junction, null))
		else:
			assert(false, "We should never get here")
		
		new_tracks.append(newTrack)
	return new_tracks
