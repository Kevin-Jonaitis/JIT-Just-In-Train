#CHAT-GPT generated, edited for correctness
extends RefCounted
class_name PriorityQueue

# Internal heap array. Each element is a dictionary with 'node' and 'cost'.
var heap: Array = []

# Returns the index of the parent node
func parent(index: int) -> int:
	return (index - 1) / 2
	
# Returns the index of the left child
func left_child(index: int) -> int:
	return 2 * index + 1
	
# Returns the index of the right child
func right_child(index: int) -> int:
	return 2 * index + 2
	
# Swaps two elements in the heap
func swap(i: int, j: int) -> void:
	var temp = heap[i]
	heap[i] = heap[j]
	heap[j] = temp

# Moves the element at index up to maintain heap property
func bubble_up(index: int) -> void:
	var current = index
	while current > 0:
		var p = parent(current)
		if heap[current]["cost"] < heap[p]["cost"]:
			swap(current, p)
			current = p
		else:
			break

# Moves the element at index down to maintain heap property
func bubble_down(index: int) -> void:
	var current = index
	while true:
		var l = left_child(current)
		var r = right_child(current)
		var smallest = current
		
		if l < heap.size() and heap[l]["cost"] < heap[smallest]["cost"]:
			smallest = l
		if r < heap.size() and heap[r]["cost"] < heap[smallest]["cost"]:
			smallest = r
		if smallest != current:
			swap(current, smallest)
			current = smallest
		else:
			break

# Inserts a VirtualNode with associated cost into the priority queue
func insert(node: VirtualNode, cost: float) -> void:
	var element = {"node": node, "cost": cost}
	heap.append(element)
	bubble_up(heap.size() - 1)

# Extracts and returns the VirtualNode with the smallest cost
func extract_min() -> VirtualNode:
	if is_empty():
		push_error("PriorityQueue is empty. Cannot extract_min.")
		return null
	
	var min_node = heap[0]["node"]
	heap[0] = heap[heap.size() - 1]
	heap.pop_back()
	if not is_empty():
		bubble_down(0)
	return min_node

# Returns the VirtualNode with the smallest cost without removing it
func peek() -> VirtualNode:
	if is_empty():
		push_error("PriorityQueue is empty. Cannot peek.")
		return null
	return heap[0]["node"]

# Checks if the priority queue is empty
func is_empty() -> bool:
	return heap.size() == 0

# Returns the size of the priority queue
func size() -> int:
	return heap.size()

# Optional: Clears the priority queue
func clear() -> void:
	heap.clear()
