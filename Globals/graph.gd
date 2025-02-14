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
var incoming_edges: Dictionary[String, Array] = {}

# Turnaround loops: node_name (String) -> Edge (loop back to itself)
var turnaround_loops: Dictionary[String, Edge] = {}

# -------------------------------------------------------------------
# Node Management
# -------------------------------------------------------------------
func add_node(node: VirtualNode) -> void:
    nodes[node.name] = node
    if not incoming_edges.has(node.name):
        incoming_edges[node.name] = []  # Array of String
    _update_all_turnaround_loops()


func remove_node(node: VirtualNode) -> void:
    var node_name: String = node.name
    nodes.erase(node_name)

    # Remove outgoing edges from this node
    if outgoing_edges.has(node_name):
        var edges_array: Array[Edge] = outgoing_edges[node_name]
        for edge: Edge in edges_array:
            var dest_name: String = edge.to_node.name
            if incoming_edges.has(dest_name):
                incoming_edges[dest_name].erase(node_name)
        outgoing_edges.erase(node_name)

    # Remove all edges that point to this node
    if incoming_edges.has(node_name):
        var from_list: Array[String] = incoming_edges[node_name]
        for from_name: String in from_list:
            if outgoing_edges.has(from_name):
                var src_edges: Array[Edge] = outgoing_edges[from_name]
                for i: int in range(src_edges.size() - 1, -1, -1):
                    if src_edges[i].to_node.name == node_name:
                        src_edges.remove_at(i)
        incoming_edges.erase(node_name)

    # Remove any turnaround loop for this node
    if turnaround_loops.has(node_name):
        turnaround_loops.erase(node_name)

    _update_all_turnaround_loops()

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


func remove_edge(from_node: VirtualNode, to_node: VirtualNode) -> void:
    var from_name: String = from_node.name
    var to_name: String = to_node.name

    if outgoing_edges.has(from_name):
        var edges_array: Array[Edge] = outgoing_edges[from_name]
        for i: int in range(edges_array.size() - 1, -1, -1):
            if edges_array[i].to_node.name == to_name:
                edges_array.remove_at(i)

    if incoming_edges.has(to_name):
        incoming_edges[to_name].erase(from_name)

    _update_all_turnaround_loops()

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
    print("Nodes: ", nodes)
    print("Outgoing Edges:")
    for node_name: String in outgoing_edges.keys():
        var edges_array: Array[Edge] = outgoing_edges[node_name]
        for edge: Edge in edges_array:
            print(
                "  ", node_name, 
                " -> ", edge.to_node.name, 
                ", cost=", edge.cost, 
                ", intermediate=", edge.intermediate_nodes.size()
            )
    print("Incoming Edges: ", incoming_edges)
    print("Turnaround Loops: ", turnaround_loops)
