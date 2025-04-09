extends RefCounted

class_name JunctionManager3D
var track: Track3D  # Added type annotation

func _init(track_: Track3D) -> void:
	self.track = track_

func setup_junctions(starting_overlay: TrackOrJunctionOverlap, ending_overlay: TrackOrJunctionOverlap) -> void:
	if (track.bezier_curve):
		assert(false, "We haven't implemented junctions for bezier curves yet")
	elif (track.dubins_path):
		create_dubin_junctions(starting_overlay, ending_overlay)
	else:
		assert(false, "We should never get here")

func create_dubin_junctions(starting_overlay: TrackOrJunctionOverlap, ending_overlay: TrackOrJunctionOverlap) -> void:
	var startingJunction: Junction
	if (starting_overlay):
		handle_track_joining_dubin(starting_overlay, true)
	else:
		var first_point: Vector2 = track.dubins_path.shortest_path._points[0]
		startingJunction = Junction.new_Junction(first_point, track.junctions, \
	Junction.NewConnection.new(track, true))
	
	# Check if our ending point overlaps our just-placed starting junction
	if (startingJunction):
		var point_to_check: Vector2
		if (ending_overlay && ending_overlay.trackPointInfo):
			point_to_check = ending_overlay.trackPointInfo.get_point()
		if (!ending_overlay):
			point_to_check = track.dubins_path.shortest_path._points[-1]
		if (point_to_check && \
		is_junction_within_search_radius(startingJunction, point_to_check)):
			startingJunction.add_connection(Junction.NewConnection.new(track, false))
			return

	if (ending_overlay):
		handle_track_joining_dubin(ending_overlay, false)
	else:
		var last_point: Vector2 = track.dubins_path.shortest_path._points[-1]
		Junction.new_Junction(last_point, track.junctions, \
		Junction.NewConnection.new(track, false)) 


func is_junction_within_search_radius(junction_one: Junction, point: Vector2) -> bool:
	if (point.distance_to(junction_one.position) <= TrackIntersectionSearcher3D.SEARCH_RADIUS):
		return true
	else:
		return false

func handle_track_joining_dubin(overlap: TrackOrJunctionOverlap, is_start_of_new_track: bool) -> void:
	if (overlap.junction):
		overlap.junction.add_connection(Junction.NewConnection.new(track, is_start_of_new_track))
	elif (overlap.trackPointInfo):
		var middle_junction: Junction = split_track_at_point(overlap.trackPointInfo)
		middle_junction.add_connection(Junction.NewConnection.new(track, is_start_of_new_track))
	else:
		assert(false, "We should never get here, we should always have a junction or track point info if we're in this function")

func split_track_at_point(trackPointInfo: TrackPointInfo) -> Junction:	
	var split_tracks: Array[Track3D] = create_split_track(trackPointInfo)
	var first_half: Track3D = split_tracks[0]
	var second_half: Track3D = split_tracks[1]
	track.trains.update_train_stops(trackPointInfo.track, first_half, second_half)
	trackPointInfo.track.delete_track()
	return split_tracks[0].end_junction

func create_split_track(trackPointInfo: TrackPointInfo) -> Array[Track3D]:
	if (!trackPointInfo.track.dubins_path):
		assert(false, "We haven't implemented split for any other type of path")
		return []
	var new_tracks : Array[Track3D] = []
	var new_dubins_paths : Array[DubinPath] = trackPointInfo.track.dubins_path.shortest_path.split_at_point_index(trackPointInfo.point_index)
	var middleJunction: Junction
	var curve_type_flag: bool = true if track.dubins_path else false
	for i: int in range(new_dubins_paths.size()):
		var newTrack: Track3D = Track3D.new_Track("SplitTrack_" + str(TrackBuilder3D.track_counter), curve_type_flag, track.tracks)
		newTrack.set_track_path_manual(new_dubins_paths[i])

		if (i == 0):
			newTrack.build_track(TrackOrJunctionOverlap.new(trackPointInfo.track.start_junction, null), null, "")
			middleJunction = newTrack.end_junction
		elif (i == 1):
			newTrack.build_track(TrackOrJunctionOverlap.new(middleJunction, null), TrackOrJunctionOverlap.new(trackPointInfo.track.end_junction, null), "")
		else:
			assert(false, "We should never get here")
		
		new_tracks.append(newTrack)
	return new_tracks
