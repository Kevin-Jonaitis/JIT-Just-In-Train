extends Area2D

@onready var collision_shape : CollisionShape2D = $IntersectionCircle
@onready var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state

# The closet track intersection point within a radius
var track_intersection = null
		
# Given the mouse position, find the track and point on the track
# that is closest to the mouse, or the endpoint point if it exists
func check_for_overlap_track():
	track_intersection = null
	position = get_global_mouse_position()
	var query = PhysicsShapeQueryParameters2D.new()
	query.transform = transform
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = 1
	query.set_shape(collision_shape.shape)

	var results = space_state.intersect_shape(query)
	var points_data = []

	var found_endpoint: bool = false

	# Gather all points (plus any extra info) into an array
	for item in results:
		if item.size() > 0:
			var track = item["collider"].get_parent()
			var point_index = item["shape"]
			var point_and_angle_at_index = track.get_point_and_tangent_at_index(point_index)

			if (point_and_angle_at_index[2] || point_and_angle_at_index[3]):
				found_endpoint = true

			points_data.append({
				"track": track,
				"point_index": point_index,
				"point": point_and_angle_at_index[0],
				"angle": point_and_angle_at_index[1],
				"is_start": point_and_angle_at_index[2],
				"is_end": point_and_angle_at_index[3]
			})

	var min_distance = INF

	# Find the point in 'points_data' closest to 'position'
	for data in points_data:
		if (found_endpoint):
			if (data["is_start"] || data["is_end"]):
				track_intersection = data
				break
		else:
			var dist = position.distance_to(data["point"])
			if dist < min_distance:
				min_distance = dist
				track_intersection = data

	# If we found something, draw it
	if track_intersection:
		get_parent().draw_circle_at_point(track_intersection["point"])
	return track_intersection
