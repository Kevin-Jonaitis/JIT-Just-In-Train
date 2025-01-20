extends Node2D

class_name Trains

var trains : Array[Train]:
	get:
		var result : Array[Train] = []
		for child in get_children():
			if (child.is_placed):
				result.append(child)
		return result			

func _on_train_placed(train: Train) -> void:
	add_child(train)

# Given an old track that's being split into 2 new tracks, update the train stops on the old track
func update_train_stops(old_track: Track, new_track_a: Track, new_track_b: Track):
	for train in trains:
		var result = train.stops.size()
		for stop_index in range(train.stops.size()):
			var virtual_node = train.stops[stop_index].forward_stop
			if (virtual_node.temp_node_track.uuid == old_track.uuid):
				var potential_point: TrackPointInfo = get_point_info_on_new_tracks(virtual_node.temp_node_location, new_track_a, new_track_b)
				if (potential_point):
					train.stops[stop_index] = train.create_stop(potential_point)

			
func get_point_info_on_new_tracks(old_point: Vector2, new_track_a: Track, new_track_b: Track) -> TrackPointInfo:
	var track_a_points = new_track_a.dubins_path.shortest_path.get_points()
	var track_b_points = new_track_b.dubins_path.shortest_path.get_points()
	for point_index in range(track_a_points.size()):
		if (old_point.distance_to(track_a_points[point_index]) < Utils.EPSILON):
			return new_track_a.get_point_info_at_index(point_index)
	for point_index in range(track_b_points.size()):
		if (old_point.distance_to(track_b_points[point_index]) < Utils.EPSILON):
			return new_track_b.get_point_info_at_index(point_index)
		
	return null
