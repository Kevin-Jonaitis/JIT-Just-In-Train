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
var nodes: Dictionary[String, VirtualNode] = {}

# Outgoing edges: from_node_name (String) -> Array of Edge
var outgoing_edges: Dictionary[String, Array] = {}

# Incoming edges: to_node_name (String) -> Array of from_node_name (String)
# ONLY USED TO HELP REMOVE NODES
var incoming_edges: Dictionary[String, Array] = {}

# Turnaround loops: node_name (String) -> Edge (loop back to itself)
var turnaround_loops: Dictionary[String, Edge] = {}

# -------------------------------------------------------------------
# Node Management
# -------------------------------------------------------------------

func get_outgoing_edges(node: VirtualNode) -> Array[Edge]:
	var connected_edges: Array[Edge] = []
	if outgoing_edges.has(node.name):
		connected_edges.assign(outgoing_edges[node.name] as Array[Edge])
	return connected_edges
	
func add_node(node: VirtualNode) -> void:
	nodes[node.name] = node
	# if not incoming_edges.has(node.name):
	# 	incoming_edges[node.name] = []  # Array of String
	# if not outgoing_edges.has(node.name):
	# 	outgoing_edges[node.name] = []  # Array of String
	_update_all_turnaround_loops()
	verify_edges()


func remove_node(node: VirtualNode) -> void:
	var node_name: String = node.name
	nodes.erase(node_name)


	# if outgoing_edges.has(node_name):
	# 	# remove_edge(

	# Remove outgoing edges from this node
	if outgoing_edges.has(node_name):
		var edges_array: Array[Edge] 
		edges_array.assign(outgoing_edges[node_name] as Array[Edge])
		for edge: Edge in edges_array:
			var dest_name: String = edge.to_node.name
			assert(incoming_edges.has(dest_name), "If an outgoing edge exists, so should the incoming one")
			if (incoming_edges[dest_name].size() == 1):
				incoming_edges.erase(dest_name)
			else:
				incoming_edges[dest_name].erase(node_name)
				
		outgoing_edges.erase(node_name)

	# Remove all edges that point to this node
	if incoming_edges.has(node_name):
		var from_list: Array[String] 
		from_list.assign(incoming_edges[node_name] as Array[String])
		for from_name: String in from_list:
			assert(outgoing_edges.has(from_name), "If an incoming edge exists, so should the outgoing one")
			var src_edges: Array[Edge]
			src_edges.assign(outgoing_edges[from_name] as Array[Edge])
			for i: int in range(src_edges.size() - 1, -1, -1):
				if src_edges[i].to_node.name == node_name:
					if (src_edges.size() == 1):
						outgoing_edges.erase(from_name)
					else:
						src_edges.remove_at(i)
		incoming_edges.erase(node_name)

	# Remove any turnaround loop for this node
	if turnaround_loops.has(node_name):
		turnaround_loops.erase(node_name)

	_update_all_turnaround_loops()
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

	if not incoming_edges.has(to_node.name):
		incoming_edges[to_node.name] = []
	incoming_edges[to_node.name].append(from_node.name)

	_update_all_turnaround_loops()

	verify_edges()



func remove_edge(from_name: String, to_name: String) -> void:
	# var from_name: String = from_node.name
	# var to_name: String = to_node.name

	if outgoing_edges.has(from_name):
		var edges_array: Array[Edge]
		edges_array.assign(outgoing_edges[from_name] as Array[Edge])
		for i: int in range(edges_array.size() - 1, -1, -1):
			if edges_array[i].to_node.name == to_name:
				if (edges_array.size() == 1):
					outgoing_edges.erase(from_name)
				else:
					edges_array.remove_at(i)

	if incoming_edges.has(to_name):
		if (incoming_edges[to_name].size() == 1):
			incoming_edges.erase(to_name)
		else:
			incoming_edges[to_name].erase(from_name)

	_update_all_turnaround_loops()
	verify_edges()

# -------------------------------------------------------------------
# Turnaround Loop Management
# -------------------------------------------------------------------
func _update_all_turnaround_loops() -> void:
	# STEP A: Validate or recalc existing loops
	for node_name: String in turnaround_loops.keys():
		var loop_edge: Edge = turnaround_loops[node_name]
		if not _is_loop_valid(node_name, loop_edge):
			var new_loop: Edge = _calculate_turnaround_loop(nodes[node_name])
			if new_loop == null:
				turnaround_loops.erase(node_name)
			else:
				turnaround_loops[node_name] = new_loop
	
	# STEP B: For nodes without a loop, try to calculate one
	for node_name: String in nodes.keys():
		if not turnaround_loops.has(node_name):
			var maybe_loop: Edge = _calculate_turnaround_loop(nodes[node_name])
			if maybe_loop != null:
				turnaround_loops[node_name] = maybe_loop	
	


func verify_edges() -> void:

	print_graph()

	# Verify the values in the outgoing arrays match the incoming arrays
	for node_name: String in outgoing_edges.keys():
		var edges_array: Array[Edge]
		edges_array.assign(outgoing_edges[node_name] as Array[Edge])
		for edge: Edge in edges_array:
			assert(incoming_edges.has(edge.to_node.name), "Outgoing edge has no incoming edge")
			assert(incoming_edges[edge.to_node.name].find(node_name) != -1, "Outgoing edge has no incoming edge") 
	
	#assert(outgoing_edges.size() == incoming_edges.size(), "Mismatched edge counts")



func _is_loop_valid(start_node_name: String, loop_edge: Edge) -> bool:
	if loop_edge == null:
		return false
	# Simulate walking the chain
	var current_name: String = start_node_name
	var chain: Array[VirtualNode] = loop_edge.intermediate_nodes

	for next_node: VirtualNode in chain:
		if not outgoing_edges.has(current_name):
			return false
		var found_edge: Edge = _find_edge_to(outgoing_edges[current_name], next_node.name)
		if found_edge == null:
			return false
		current_name = next_node.name
	
	# Then from the last intermediate node to the start node
	if not outgoing_edges.has(current_name):
		return false
	var closing_edge: Edge = _find_edge_to(outgoing_edges[current_name], start_node_name)
	if closing_edge == null:
		return false

	return true


func _find_edge_to(edges_array: Array[Edge], target_name: String) -> Edge:
	for e: Edge in edges_array:
		if e.to_node and e.to_node.name == target_name:
			return e
	return null

# -------------------------------------------------------------------
# Placeholder: your loop-finding function
# -------------------------------------------------------------------
func _calculate_turnaround_loop(node: VirtualNode) -> Edge:
	# Implement your own logic to build an Edge that represents a cycle
	# from node.name -> ... -> node.name.
	# Return null if none is found.
	return null

# -------------------------------------------------------------------
# Debug
# -------------------------------------------------------------------
func print_graph() -> void:
	print("")
	# Build a dictionary mapping node_name -> a more readable description.
	var node_debug_map: Dictionary[String, String] = {}
	for node_name: String in nodes.keys():
		var node_obj : VirtualNode = nodes[node_name]
		# For now, just store the node's name (or any short identifier).
		# If your VirtualNode has a custom method like get_debug_string(), you could call that here.
		node_debug_map[node_name] = "VirtualNode(name=" + node_obj.name + ")"

	# Now print the debug dictionary instead of the raw 'nodes' dictionary.
	# print("Nodes: ", node_debug_map)
	print("Nodes:")
	for node_name: String in node_debug_map.keys():
		var node_obj: String = node_debug_map[node_name]
		# Print the node's name and any other relevant info
		print("  ", node_name, " -> ", node_obj)


	# Print outgoing edges as before
	print("Outgoing Edges:")
	for node_name: String in outgoing_edges.keys():
		var edges_array: Array[Edge]
		edges_array.assign(outgoing_edges[node_name] as Array[Edge])
		for edge: Edge in edges_array:
			print(
				"  ", node_name, 
				" -> ", edge.to_node.name, 
				", cost=", edge.cost, 
				", intermediate=", edge.intermediate_nodes.size()
			)

	# Print incoming edges as before
	print("Incoming Edges: ")
	for incoming_edge: String in incoming_edges.keys():
		var from_list: Array[String] 
		from_list.assign(incoming_edges[incoming_edge] as Array[String])
		print("  ", incoming_edge, " -> ", from_list)
	
	print("Turaround Nodes: ")
	for loop_node_name: String in turnaround_loops.keys():
		var loop_edge: Edge = turnaround_loops[loop_node_name]
		# Summarize the loop edge in a short string
		print("Edge(to=" + loop_edge.to_node.name + ", cost=" + str(loop_edge.cost) + ")")
