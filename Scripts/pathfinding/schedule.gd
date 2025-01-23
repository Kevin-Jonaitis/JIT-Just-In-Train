extends RefCounted

class_name Schedule

# path between each pair of stops
var stops_path: Array[Path]

func _init(stops_path: Array[Path]):
	self.stops_path = stops_path

var stops: Array[VirtualNode]:
	get:
		var stops_temp = []
		for path in stops_path:
			stops.append(path.nodes[0])
		# Append last stop of last node
		stops_temp.append(stops_path[-1].nodes[-1])
		return stops
	set(value):
		assert(false, "Cannot set stops") 

# func _init():
	# self.stops = stops
	# self.schedule = schedule

func add_path(path: Path):
	stops_path.append(path)
