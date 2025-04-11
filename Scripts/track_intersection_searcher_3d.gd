extends RefCounted

class_name TrackIntersectionSearcher3D

var space_state: PhysicsDirectSpaceState3D

# The closet track intersection point within a radius
var track_intersection: TrackPointInfo = null
# Search so that if our cursor is forced to the grid, it will at least be included in the serach radius
const SEARCH_RADIUS: float = 1.0
var parent_node: Node3D

func _init(parent_node_: Node3D) -> void:
	space_state = 	parent_node_.get_world_3d().direct_space_state
	parent_node = parent_node_

func check_for_junctions_or_track_at_position(position: Vector2) -> TrackOrJunctionOverlap:
	var junction: Junction = check_for_junction_at_position(position)
	if junction:
		return TrackOrJunctionOverlap.new(junction, null)
		
	var track_point: TrackPointInfo = check_for_overlaps_at_position(position)
	if track_point:
		return TrackOrJunctionOverlap.new(null, track_point)
	return null


static func check_for_stops_at_position(track_or_junction: TrackOrJunctionOverlap) -> bool:
	# assert(track_or_junction, "We shouldn't call this with null")
	# Can't have a stop at a junction, so short circuit
	if (track_or_junction == null || track_or_junction.junction):
		return false
	
	var point_info: TrackPointInfo = track_or_junction.trackPointInfo
	var track_to_test : Track3D = point_info.track
	var position: Vector2 = point_info.get_point()

	var stops : Array[Stop] = Utils.get_all_stops()
	for stop: Stop in stops:
		var train : Train = stop.get_train()
		var minimum_required_distance: float = train.length -  (train.cart_length / 2)
		for train_pos: Stop.TrainPosition in stop.stop_option:
			if (train_pos.front_of_train.track.uuid != track_to_test.uuid):
				continue
			if ((train_pos.front_of_train.track.uuid == track_to_test.uuid && 
			train_pos.front_of_train.get_vector_pos().distance_to(position) < minimum_required_distance) ||
			(train_pos.back_of_train.track.uuid == track_to_test.uuid 
			&& train_pos.back_of_train.get_vector_pos().distance_to(position) < minimum_required_distance)):
				return true
	return false

func check_for_collision(position: Vector2, mask: int) -> Array[Dictionary]:
	track_intersection = null
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	# Create a CircleShape2D with the desired radius
	var circle_shape: SphereShape3D = SphereShape3D.new()
	circle_shape.radius = SEARCH_RADIUS
	
	query.transform = Transform3D(Basis.IDENTITY, Vector3(position.x, 0, position.y))  # Center the shape at the passed position
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = mask
	query.set_shape(circle_shape)
	return space_state.intersect_shape(query)

func check_for_junction_at_position(position: Vector2) -> Junction:
	var junctions_found: Array[Junction] = []
	var results: Array[Dictionary] = check_for_collision(position, 4) # value 4 = bitmask 3
	for item: Dictionary in results:
		if item.size() > 0:
			var junction: Junction = (item["collider"] as Area3D).get_parent()
			junctions_found.append(junction)
		
	if (junctions_found.size() > 0):
		if (junctions_found.size() > 1):
			push_error("We found more than one junction at this position, something's wrong with our selector")
		return junctions_found[0]

	return null


# Pass in a position, and get the closet point to this position WITHIN the search radius
func check_for_overlaps_at_position(position: Vector2, bit_mask: int = 1) -> TrackPointInfo:
	track_intersection = null
	var results: Array[Dictionary] = check_for_collision(position, bit_mask)

	var points_data: Array[TrackPointInfo] = []

	# Gather all points (plus any extra info) into an array
	for item: Dictionary in results:
		if item.size() > 0:
			var track: Track3D = (item["collider"] as Area3D).get_parent()
			var point_index: int = item["shape"]
			#if (point_index == 0 || point_index == track.dubins_path.shortest_path.get_points().size() - 1):
					#assert(false, "We shouldn't select a point at either end here, that should be a junction!!")

			var pointInfo: TrackPointInfo = track.get_point_info_at_index(point_index)

			points_data.append(pointInfo)

	var min_distance: float = INF

	# Find the point in 'points_data' closest to 'position'
	for data: TrackPointInfo in points_data:
		var dist: float = position.distance_to(data.get_point())
		if dist < min_distance:
			min_distance = dist
			track_intersection = data

	# If we found something, draw it
	#if track_intersection:
		#parent_node.draw_circle_at_point(track_intersection.get_point())
	return track_intersection


func get_train_collision_info(position: Vector2) -> Array[Train]:
	var trains: Array[Train] = []
	var results: Array[Dictionary] = check_for_collision(position, Train.TRAIN_COLLISION_LAYER)
	for item: Dictionary in results:
		if item.size() > 0:
			var train: Train = (item["collider"] as Area3D).get_parent().get_parent().get_parent()
			trains.append(train)

	return trains
