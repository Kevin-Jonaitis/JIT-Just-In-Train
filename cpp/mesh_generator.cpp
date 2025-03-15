#include "mesh_generator.h"
#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void MeshGenerator::_bind_methods() {
	ClassDB::bind_static_method("MeshGenerator", D_METHOD("extrude_polygon_along_path_arraymesh", "polygon_2d", "path_points", "out_mesh"), 
	&MeshGenerator::extrude_polygon_along_path_arraymesh);

}

MeshGenerator::MeshGenerator() {
}

MeshGenerator::~MeshGenerator() {
	// Add your cleanup here.
}

void MeshGenerator::extrude_polygon_along_path_arraymesh(
	const PackedVector2Array &polygon_2d,
	const PackedVector3Array &path_points,
	const Ref<ArrayMesh> &out_mesh) {
	print_line("Extruding polygon along path...");
	// Implementation for extruding a polygon along a path to create a mesh.
	// This function would typically involve creating vertices and indices
	// based on the provided polygon and path points.
}