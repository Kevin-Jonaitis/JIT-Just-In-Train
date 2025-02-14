# # warnings-disable
# extends GutTest

# # const Graph: Type = preload("res://Graph.gd")
# # const Edge: Type = preload("res://Edge.gd")
# # var junctionNode: Resource = load("res://Scripts/pathfinding/nodes/junction_node.gd")
# # Create a stub for JunctionNode.
# # var stub_junction_node: VirtualNode = double("JunctionNode", {
# # 	"name": "Junction_Stub",
# # 	"add_connected_node": func(vnode: VirtualNode, cost: float) -> void:
# # 		pass,
# # 	"get_connected_nodes": func(train: Object, fetch_junctions_only: bool = false) -> Array:
# # 		return []
# # }) as VirtualNode

# # # Similarly, a stub for StopNode if needed.
# # var stub_stop_node: VirtualNode = double("StopNode", {
# # 	"name": "Stop_Stub",
# # 	"get_distance_from_front_track": func() -> float:
# # 		return 0.0
# # }) as VirtualNode

# # A helper function to create a VirtualNode double for testing purposes.
# func create_virtual_node_stub(name_str: String) -> VirtualNode:
# 	stub(JunctionNode, '_init').param_defaults([null, null, true, true])
# 	stub(JunctionNode, 'generate_name').to_return(name_str)

# 	# stub(JunctionNode, 'new').param_defaults([null, null, true, true])

# 	var result : Resource = double(JunctionNode)
	
# 	return result.new()

# 	#   stub(MyScript, "some_method").to_return(111)

# 	# return double("VirtualNode", {"name": name_str}) as VirtualNode

# func test_add_node_with_stub() -> void:
# 	# Use our stubbed JunctionNode as a VirtualNode.
# 	var vnode: VirtualNode = create_virtual_node_stub("Junction_Stub")
# 	Graph.add_node(vnode)
# #     assert_true(graph.nodes.has(vnode.name), "Graph should contain the stubbed virtual node.")

# # func test_add_edge_with_stub_nodes() -> void:
# #     var graph: Graph = Graph.new()
# #     var node_a: VirtualNode = create_virtual_node_stub("A")
# #     var node_b: VirtualNode = create_virtual_node_stub("B")
# #     graph.add_node(node_a)
# #     graph.add_node(node_b)
# #     graph.add_edge(node_a, node_b, 12.0)
# #     var out_edges: Array = graph.get_outgoing_edges(node_a)
# #     assert_eq(out_edges.size(), 1, "There should be one outgoing edge from node A.")
# #     var edge_inst: Edge = out_edges[0] as Edge
# #     assert_eq(edge_inst.to_node.name, "B", "Edge from A should point to node B.")
# #     assert_eq(edge_inst.cost, 12.0, "Edge cost should be 12.0.")
# #     # Check incoming edges for B.
# #     assert_true(graph.incoming_edges.has("B"), "Node B should have incoming edges.")
# #     assert_true((graph.incoming_edges["B"] as Array).find("A") != -1, "Incoming edges for B should contain A.")

# # func test_remove_node_with_stub() -> void:
# #     var graph: Graph = Graph.new()
# #     var node_a: VirtualNode = create_virtual_node_stub("A")
# #     var node_b: VirtualNode = create_virtual_node_stub("B")
# #     graph.add_node(node_a)
# #     graph.add_node(node_b)
# #     graph.add_edge(node_a, node_b, 5.0)
# #     graph.remove_node(node_b)
# #     assert_false(graph.nodes.has("B"), "Graph should not contain node B after removal.")
# #     var out_edges: Array = graph.get_outgoing_edges(node_a)
# #     for edge in out_edges:
# #         assert_false(edge.to_node.name == "B", "No outgoing edge from A should point to B after removal.")
# #     assert_false(graph.incoming_edges.has("B"), "Incoming edges for B should be removed after node removal.")
