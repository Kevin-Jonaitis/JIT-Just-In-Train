extends RefCounted

class_name Schedule

# path between each pair of stops
var paths: Array[Path]
var stops: Array[StopNode]:

	get:
		var stops_temp : Array[StopNode] = []
		for path : Path in paths:
			stops_temp.append(path.nodes[0])
		# Append last stop of last node
		stops_temp.append(paths[-1].nodes[-1])
		return stops_temp
	set(value):
		assert(false, "Cannot set stops") 

func _init(stops_path_: Array[Path]) -> void:
	self.paths = stops_path_


func get_path(stop_index: int) -> Path:
	return paths[stop_index]


func get_new_location(location: Location, new_progress: float) -> Location:
	var current_stop_index: int = location.stop_index
	var path: Path = paths[current_stop_index]
	var results: Path.PathLocation = path.get_new_position(location.track_segment_index, location.track_segment_progress, new_progress)

	while (results.overshoot):
		current_stop_index += 1
		if (current_stop_index == paths.size()): # We overshot the whole schedule
			var overshoot_location: Location = Location.new()
			overshoot_location.set_overshoot(results.overshoot)
			return overshoot_location
		path = paths[current_stop_index]
		results = path.get_new_position(location.track_segment_index, location.track_segment_progress, new_progress)

	assert(location.overshoot == 0, "Overshoot should be 0")

	var new_location: Location = Location.new()
	new_location.position = results.position
	new_location.path_index = current_stop_index
	new_location.track_segment_index = results.track_segment_index
	new_location.track_segment_progress = results.track_segment_progress
	return new_location


func add_path(path: Path) -> void:
	paths.append(path)

func get_start_node() -> StopNode:
	if (stops.size() == 0):
		return null
	return stops[0]

func get_end_node() -> StopNode:
	if (stops.size() == 0):
		return null
	return stops[-1]
