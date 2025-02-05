extends Node

@onready var junctions: Junctions = $"../../Junctions"


func get_junctions() -> Array[Junction]:
	var junction_objs: Array[Junction] = []
	for junction: Node in junctions.get_children():
		if (junction is Junction):
			junction_objs.append(junction)
		else:
			assert(false,"Something went horribly wrong")
	return junction_objs
