extends RefCounted

class_name TrackIntersectionSearcher

var space_state: PhysicsDirectSpaceState2D

# The closet track intersection point within a radius
var track_intersection = null
# Search so that if our cursor is forced to the grid, it will at least be included in the serach radius
const SEARCH_RADIUS = 18 
var parent_node: Node2D

func _init(parent_node_: Node2D) -> void:
	space_state = 	parent_node_.get_world_2d().direct_space_state
	parent_node = parent_node_

func check_for_junctions_or_track_at_position(position: Vector2) -> TrackOrJunctionOverlap:
	var junction = check_for_junction_at_position(position)
	if junction:
		return TrackOrJunctionOverlap.new(junction, null)
		
	var track_point = check_for_overlaps_at_position(position)
	if track_point:
		return TrackOrJunctionOverlap.new(null, track_point)
	return null


func check_for_collision(position: Vector2, mask: int) -> Array[Dictionary]:
	track_intersection = null
	var query = PhysicsShapeQueryParameters2D.new()
	# Create a CircleShape2D with the desired radius
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = SEARCH_RADIUS
	query.transform = Transform2D(0, position)  # Center the shape at the passed position
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = mask
	query.set_shape(circle_shape)
	return space_state.intersect_shape(query)

func check_for_junction_at_position(position: Vector2):
	var junctions_found = []
	var results = check_for_collision(position, 4) # value 4 = bitmask 3
	for item in results:
		if item.size() > 0:
			var junction: Junction = item["collider"].get_parent()
			junctions_found.append(junction)
		
	if (junctions_found.size() > 0):
		if (junctions_found.size() > 1):
			push_error("We found more than one junction at this position, something's wrong with our selector")
		return junctions_found[0]


# Pass in a position, and get the closet point to this position WITHIN the search radius
func check_for_overlaps_at_position(position: Vector2, bit_mask: int = 1) -> TrackPointInfo:
	track_intersection = null
	var results = check_for_collision(position, bit_mask)

	var points_data: Array[TrackPointInfo] = []

	# Gather all points (plus any extra info) into an array
	for item in results:
		if item.size() > 0:
			var track: Track = item["collider"].get_parent()
			var point_index = item["shape"]
			#if (point_index == 0 || point_index == track.dubins_path.shortest_path.get_points().size() - 1):
					#assert(false, "We shouldn't select a point at either end here, that should be a junction!!")

			var pointInfo: TrackPointInfo = track.get_point_info_at_index(point_index)

			points_data.append(pointInfo)

	var min_distance = INF

	# Find the point in 'points_data' closest to 'position'
	for data in points_data:
		var dist = position.distance_to(data.get_point())
		if dist < min_distance:
			min_distance = dist
			track_intersection = data

	# If we found something, draw it
	#if track_intersection:
		#parent_node.draw_circle_at_point(track_intersection.get_point())
	return track_intersection


func get_train_collision_info(position: Vector2) -> Array[Node2D]:
	var trains : Array[Node2D] = []
	var results = check_for_collision(position, Train.TRAIN_COLLISION_LAYER)
	for item in results:
		if item.size() > 0:
			var train: Node2D = item["collider"].get_parent()
			trains.append(train)

	return trains
