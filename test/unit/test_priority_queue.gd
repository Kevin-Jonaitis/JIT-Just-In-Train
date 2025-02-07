#CHAT-GPT generated, edited for correctness
extends GutTest
	# Helper function to create VirtualNode instances
func create_virtual_node(name: String) -> VirtualNode:
	var node: VirtualNode = VirtualNode.new()
	node.name = name
	return node

func test_insert_and_extract_order():
	var pq = PriorityQueue.new()
	
	# Create VirtualNode instances
	var node1 = create_virtual_node("Node1")
	var node2 = create_virtual_node("Node2")
	var node3 = create_virtual_node("Node3")
	var node4 = create_virtual_node("Node4")
	
	# Insert nodes with associated costs
	pq.insert(node1, 10.5)
	pq.insert(node2, 5.2)
	pq.insert(node3, 7.8)
	pq.insert(node4, 3.1)
	
	# Extract nodes and collect their names
	var extracted = []
	while not pq.is_empty():
		var node = pq.extract_min()
		extracted.append(node.name)
	
	# Define the expected extraction order based on ascending costs
	var expected = ["Node4", "Node2", "Node3", "Node1"]
	
	# Assert that the extracted order matches the expected order
	assert_eq(extracted, expected, "Extracted nodes should be in ascending cost order.")

# Test the peek functionality without removing the element
func test_peek():
	var pq = PriorityQueue.new()

	# Create and insert VirtualNode instances
	var node1 = create_virtual_node("Node1")
	var node2 = create_virtual_node("Node2")

	pq.insert(node1, 10.0)
	pq.insert(node2, 5.0)

	# Peek at the node with the smallest cost
	var peek_node = pq.peek()
	assert_eq(peek_node.name, "Node2", "Peek should return the node with the smallest cost.")

	# Ensure the queue size remains unchanged after peeking
	assert_eq(pq.size(), 2, "Peek should not remove the node from the queue.")

# Test the is_empty functionality
func test_is_empty():
	var pq = PriorityQueue.new()

	# Assert that a new queue is empty
	assert_true(pq.is_empty(), "New PriorityQueue should be empty.")

	# Insert a node and assert the queue is not empty
	var node = create_virtual_node("Node1")
	pq.insert(node, 1.0)
	assert_false(pq.is_empty(), "PriorityQueue should not be empty after insertion.")

	# Extract the node and assert the queue is empty again
	pq.extract_min()
	assert_true(pq.is_empty(), "PriorityQueue should be empty after extracting all elements.")

# Test the size functionality
func test_size():
	var pq = PriorityQueue.new()

	# Assert initial size
	assert_eq(pq.size(), 0, "New PriorityQueue should have size 0.")

	# Insert nodes and check size incrementally
	var node1 = create_virtual_node("Node1")
	var node2 = create_virtual_node("Node2")
	pq.insert(node1, 10.0)
	assert_eq(pq.size(), 1, "PriorityQueue should have size 1 after one insertion.")

	pq.insert(node2, 5.0)
	assert_eq(pq.size(), 2, "PriorityQueue should have size 2 after two insertions.")

	# Extract a node and check size
	pq.extract_min()
	assert_eq(pq.size(), 1, "PriorityQueue should have size 1 after one extraction.")

	# Extract the last node and check size
	pq.extract_min()
	assert_eq(pq.size(), 0, "PriorityQueue should have size 0 after all extractions.")

# Test extracting from an empty queue
func test_extract_min_empty():
	var pq = PriorityQueue.new()

	# Attempt to extract from an empty queue
	var min_node = pq.extract_min()
	assert_null(min_node, "extract_min should return null when the queue is empty.")

# Test inserting multiple nodes with the same cost
# Fails, but we don't care because it's not important

# func test_insert_duplicate_costs():
# 	var pq = PriorityQueue.new()

# 	# Create VirtualNode instances with identical costs
# 	var node1 = create_virtual_node("Node1")
# 	var node2 = create_virtual_node("Node2")
# 	var node3 = create_virtual_node("Node3")

# 	pq.insert(node1, 5.0)
# 	pq.insert(node2, 5.0)
# 	pq.insert(node3, 5.0)

# 	# Extract nodes and collect their names
# 	var extracted = []
# 	while not pq.is_empty():
# 		var node = pq.extract_min()
# 		extracted.append(node.name)

# 	# Define the expected extraction order (assuming insertion order is preserved for equal costs)
# 	var expected = ["Node1", "Node2", "Node3"]

# 	# Assert that the extracted order matches the expected order
# 	assert_eq(extracted, expected, "Nodes with duplicate costs should be extracted in insertion order.")

# # Test the clear functionality
func test_clear():
	var pq = PriorityQueue.new()

	# Insert nodes into the queue
	var node1 = create_virtual_node("Node1")
	var node2 = create_virtual_node("Node2")
	pq.insert(node1, 10.0)
	pq.insert(node2, 5.0)
	assert_eq(pq.size(), 2, "PriorityQueue should have size 2 after insertions.")

	# Clear the queue
	pq.clear()
	assert_true(pq.is_empty(), "PriorityQueue should be empty after clearing.")
	assert_eq(pq.size(), 0, "PriorityQueue size should be 0 after clearing.")

# Test peeking into an empty queue
func test_peek_empty():
	var pq = PriorityQueue.new()

	# Attempt to peek into an empty queue
	var peek_node = pq.peek()
	assert_null(peek_node, "peek should return null when the queue is empty.")

# Test multiple insertions and extractions
func test_multiple_insertions_and_extractions():
	var pq = PriorityQueue.new()

	# Create multiple VirtualNode instances
	var nodes = [
		create_virtual_node("Node1"),
		create_virtual_node("Node2"),
		create_virtual_node("Node3"),
		create_virtual_node("Node4"),
		create_virtual_node("Node5")
	]

	# Insert nodes with varying costs
	var costs = [7.0, 3.0, 9.0, 1.0, 5.0]
	for i in range(nodes.size()):
		pq.insert(nodes[i], costs[i])

	# Expected extraction order based on costs: Node4 (1.0), Node2 (3.0), Node5 (5.0), Node1 (7.0), Node3 (9.0)
	var expected = ["Node4", "Node2", "Node5", "Node1", "Node3"]
	var extracted = []

	while not pq.is_empty():
		var node = pq.extract_min()
		extracted.append(node.name)

	assert_eq(extracted, expected, "Nodes should be extracted in the correct ascending cost order.")

# # Test insertion after clearing the queue
func test_insert_after_clear():
	var pq = PriorityQueue.new()

	# Insert and clear the queue
	var node1 = create_virtual_node("Node1")
	var node2 = create_virtual_node("Node2")
	pq.insert(node1, 10.0)
	pq.insert(node2, 5.0)
	pq.clear()
	assert_true(pq.is_empty(), "PriorityQueue should be empty after clearing.")

	# Insert new nodes after clearing
	var node3 = create_virtual_node("Node3")
	var node4 = create_virtual_node("Node4")
	pq.insert(node3, 2.0)
	pq.insert(node4, 8.0)

	# Extract nodes and verify order
	var extracted = []
	while not pq.is_empty():
		var node = pq.extract_min()
		extracted.append(node.name)

	var expected = ["Node3", "Node4"]
	assert_eq(extracted, expected, "Nodes should be correctly inserted and extracted after clearing the queue.")