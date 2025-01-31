extends RefCounted

class_name Schedule

# path between each pair of stops
var stops_path: Array[Path]

func _init(stops_path_: Array[Path]) -> void:
	self.stops_path = stops_path_
var stops: Array[VirtualNode]:

	get:
		var stops_temp : Array[VirtualNode] = []
		for path : Path in stops_path:
			stops_temp.append(path.nodes[0])
		# Append last stop of last node
		stops_temp.append(stops_path[-1].nodes[-1])
		return stops_temp
	set(value):
		assert(false, "Cannot set stops") 

# func _init():
	# self.stops = stops
	# self.schedule = schedule

func add_path(path: Path) -> void:
	stops_path.append(path)
