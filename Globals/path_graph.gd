extends Node

# External classes:
#   class_name VirtualNode:
#       var name: String  (immutable once set)
#       # ...
#
#   class_name Edge (extends RefCounted):
#       static var COST_TO_REVERSE: float = 100
#       var to_node: VirtualNode
#       var cost: float
#       var intermediate_nodes: Array[VirtualNode]
#       var name: String
#
#       func _init(node_: VirtualNode, cost_: float, intermediate_nodes_: Array[VirtualNode] = []) -> void:
#           to_node = node_
#           cost = cost_
#           intermediate_nodes = intermediate_nodes_
#           name = Utils.generate_uuid()

# -------------------------------------------------------------------
# Data Structures
# -------------------------------------------------------------------
# Nodes: node name (String) -> VirtualNode
var _nodes: Dictionary[String, VirtualNode] = {}

# Outgoing edges: from_node_name (String) -> Array of Edge
var outgoing_edges: Dictionary[String, Array] = {}

# Incoming edges: to_node_name (String) -> Array of from_node_name (String)
# ONLY USED TO HELP REMOVE NODES
var _incoming_edges: Dictionary[String, Array] = {}

# Turnaround loops: node_name (String) -> Edge (loop back to itself)
var turnaround_loops: Dictionary[String, Edge] = {}

# Needs to be kept in sync with _nodes
# I'll probably regret this later
var exit_nodes: Array[JunctionNode] = []


# Turnaround loops by train: train name (String) -> Dictionary 
#   (inner Dictionary: node name (String) -> Edge)
var turnaround_loops_by_train: Dictionary[String, Dictionary] = {}

@onready var trains: Trains = Utils.get_node_by_ground_name("trains")
var update_turnaround_loops_dirty: bool = false

# -------------------------------------------------------------------
# Node Management
# -------------------------------------------------------------------

func get_connected_edges(node: VirtualNode, train: Train, get_turnarounds: bool = true) -> Array[Edge]:
	assert(train, "Train must be provided")
	var connected_edges: Array[Edge] = []
	if outgoing_edges.has(node.name):
		# Get the actual array (no assign(), so changes affect the stored array)
		connected_edges.assign(outgoing_edges[node.name] as Array[Edge])
	
	# Lookup turnaround loops for this train (keyed by train.name)
	if (get_turnarounds):
		var train_key: String = train.name
		if turnaround_loops_by_train.has(train_key):
			var loops: Dictionary = turnaround_loops_by_train[train_key] as Dictionary
			if loops.has(node.name):
				connected_edges.append(loops[node.name] as Edge)
	return connected_edges
	
func add_node(node: VirtualNode) -> void:
	_nodes[node.name] = node
	exit_nodes = get_all_exit_nodes()
	verify_edges()



func remove_node(node: VirtualNode) -> void:
	var node_name: String = node.name
	_nodes.erase(node_name)
	exit_nodes = get_all_exit_nodes()

	# Remove outgoing edges from this node
	if outgoing_edges.has(node_name):
		for edge: Edge in outgoing_edges[node_name]:
			var dest_name: String = edge.to_node.name
			assert(_incoming_edges.has(dest_name), "If an outgoing edge exists, so should the incoming one")
			if (_incoming_edges[dest_name].size() == 1):
				_incoming_edges.erase(dest_name)
			else:
				_incoming_edges[dest_name].erase(node_name)
				
		outgoing_edges.erase(node_name)

	# Remove all edges that point to this node
	if _incoming_edges.has(node_name):
		for from_name: String in _incoming_edges[node_name]:
			assert(outgoing_edges.has(from_name), "If an incoming edge exists, so should the outgoing one")
			var src_edges: Array = outgoing_edges[from_name]
			for i: int in range(src_edges.size() - 1, -1, -1):
				if src_edges[i].to_node.name == node_name:
					if (src_edges.size() == 1):
						outgoing_edges.erase(from_name)
					else:
						src_edges.remove_at(i)
		_incoming_edges.erase(node_name)

	# Remove any turnaround loop for this node from every train's dictionary
	for train_key: String in turnaround_loops_by_train.keys():
		var loops: Dictionary = turnaround_loops_by_train[train_key] as Dictionary
		if loops.has(node_name):
			loops.erase(node_name)

	verify_edges()


# -------------------------------------------------------------------
# Edge Management
# -------------------------------------------------------------------
func add_edge(from_node: VirtualNode, to_node: VirtualNode, cost: float) -> void:
	var edge: Edge = Edge.new(to_node, cost)
	edge.intermediate_nodes = []  # For non-turnaround edges, remains empty

	if not outgoing_edges.has(from_node.name):
		outgoing_edges[from_node.name] = []
	outgoing_edges[from_node.name].append(edge)

	if not _incoming_edges.has(to_node.name):
		_incoming_edges[to_node.name] = []
	_incoming_edges[to_node.name].append(from_node.name)

	verify_edges()



func remove_edge(from_name: String, to_name: String) -> void:
	# var from_name: String = from_node.name
	# var to_name: String = to_node.name

	if outgoing_edges.has(from_name):
		var edges_array: Array = outgoing_edges[from_name]
		for i: int in range(edges_array.size() - 1, -1, -1):
			if edges_array[i].to_node.name == to_name:
				if (edges_array.size() == 1):
					outgoing_edges.erase(from_name)
				else:
					edges_array.remove_at(i)

	if _incoming_edges.has(to_name):
		if (_incoming_edges[to_name].size() == 1):
			_incoming_edges.erase(to_name)
		else:
			_incoming_edges[to_name].erase(from_name)

	verify_edges()

# -------------------------------------------------------------------
# Turnaround Loop Management (Per-Train)
# -------------------------------------------------------------------
# New public function that updates turnaround loops for a given train.
func update_turnaround_loops_for_train(train: Train) -> void:
	var junction_nodes: Array[JunctionNode] = exit_nodes
	for junction_node: JunctionNode in junction_nodes:
		var node_name: String = junction_node.name
		if turnaround_loops.has(node_name):
			var loop_edge: Edge = turnaround_loops[node_name]
			if not _is_loop_valid(node_name, loop_edge):
				_calculate_and_set_turnaround_loop(junction_node, train)
		else:
			# Otherwise, try to calculate one.
			_calculate_and_set_turnaround_loop(junction_node, train)
			

# TODO: This might not actually be much better than just recalcuating all loops every time.
func _is_loop_valid(start_node_name: String, loop_edge: Edge) -> bool:
	if loop_edge == null:
		return false
	# Simulate walking the chain for this specific train.
	var current_name: String = start_node_name
	var chain: Array[VirtualNode] = loop_edge.intermediate_nodes  # Expected to be Array of VirtualNode

	for next_node: VirtualNode in chain:
		if (next_node is StopNode): # Don't find connections for stop _nodes because they're dynamically created
			continue
		if not outgoing_edges.has(current_name):
			return false
		var found_edge: Edge = _find_edge_to(outgoing_edges[current_name], next_node.name)
		if found_edge == null:
			return false
		current_name = next_node.name
	
	# Then from the last intermediate node back to the start node
	if not outgoing_edges.has(current_name):
		return false
	var closing_edge: Edge = _find_edge_to(outgoing_edges[current_name], start_node_name)
	if closing_edge == null:
		return false

	# Optionally, add train-specific validations (e.g. ensure the path length is sufficient for the train)
	# For example:
	# if (calculate_total_cost(loop_edge) < train.length):
	#     return false

	return true


func _calculate_and_set_turnaround_loop(node: JunctionNode, train: Train) -> void:
	assert(node.is_exit_node(), "Turnaround loops are only valid for exit _nodes")
	var reverse_edge: Edge = node.get_reverse_edge(train)
	var train_key: String = train.name
	# If no turnaround loops exist for this train yet, create a new dictionary.
	if not turnaround_loops_by_train.has(train_key):
		turnaround_loops_by_train[train_key] = {}
	# Retrieve the inner dictionary (mapping node name -> Edge)
	var loops: Dictionary = turnaround_loops_by_train[train_key] as Dictionary
	# Add or update the turnaround loop for the given junction.
	if (reverse_edge != null):
		loops[node.name] = reverse_edge
	else:
		loops.erase(node.name)

	# var junction_nodes: Array[JunctionNode] = get_all_exit_nodes()
	# for junction_node: JunctionNode in junction_nodes:
		


func get_all_exit_nodes() -> Array[JunctionNode]:
	var exit_nodes: Array[JunctionNode] = []
	for node_name: String in _nodes.keys():
		var node: VirtualNode = _nodes[node_name]
		if node is JunctionNode && (node as JunctionNode).is_exit_node():
			exit_nodes.append(node as JunctionNode)
	
	return exit_nodes

func _find_edge_to(edges_array: Array, target_name: String) -> Edge:
	for e: Edge in edges_array:
		if e.to_node and e.to_node.name == target_name:
			return e
	return null



func verify_edges() -> void:
	pass
	# # Verify the values in the outgoing arrays match the incoming arrays
	# for node_name: String in outgoing_edges.keys():
	# 	var edges_array: Array = outgoing_edges[node_name]
	# 	for edge: Edge in edges_array:
	# 		assert(_incoming_edges.has(edge.to_node.name), "Outgoing edge has no incoming edge")
	# 		assert(_incoming_edges[edge.to_node.name].find(node_name) != -1, "Outgoing edge has no incoming edge") 
	

# -------------------------------------------------------------------
# Debug
# -------------------------------------------------------------------
func print_graph() -> void:
	print("")
	# Build a dictionary mapping node_name -> a more readable description.
	var node_debug_map: Dictionary[String, String] = {}
	for node_name: String in _nodes.keys():
		var node_obj : VirtualNode = _nodes[node_name]
		# For now, just store the node's name (or any short identifier).
		# If your VirtualNode has a custom method like get_debug_string(), you could call that here.
		node_debug_map[node_name] = "VirtualNode(name=" + node_obj.name + ")"

	# Now print the debug dictionary instead of the raw '_nodes' dictionary.
	# print("Nodes: ", node_debug_map)
	print("Nodes:")
	for node_name: String in node_debug_map.keys():
		# Print the node's name and any other relevant info
		print("  ", node_name)


	# Print outgoing edges as before
	print("Outgoing Edges:")
	for node_name: String in outgoing_edges.keys():
		var edges_array: Array[Edge]
		edges_array.assign(outgoing_edges[node_name] as Array[Edge])
		for edge: Edge in edges_array:
			print(
				"  ", node_name, 
				" -> ", edge.to_node.name, 
				", cost=", edge.cost
			)

	# Print incoming edges as before
	print("Incoming Edges: ")
	for incoming_edge: String in _incoming_edges.keys():
		var from_list: Array[String] 
		from_list.assign(_incoming_edges[incoming_edge] as Array[String])
		print("  ", incoming_edge, " -> ", from_list)
	
	print("Turnaround Loops By Train:")
	for train_key: String in turnaround_loops_by_train.keys():
		var loops: Dictionary = turnaround_loops_by_train[train_key]
		print("  Train: ", train_key)
		for node_name: String in loops.keys():
			var loop_edge: Edge = loops[node_name]
			var node_list: String = ""
			for node: VirtualNode in loop_edge.intermediate_nodes:
				node_list += node.name + ", "
			print("    ", node_name, " -> Edge(to=", loop_edge.to_node.name, ", list=", node_list, " cost=", str(loop_edge.cost), ")")
