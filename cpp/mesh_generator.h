#ifndef MESH_GENERATOR_H
#define MESH_GENERATOR_H

#include <godot_cpp/classes/array_mesh.hpp>
#include <godot_cpp/variant/typed_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include <godot_cpp/classes/ref_counted.hpp>


namespace godot {

	class MeshGenerator : public RefCounted {
		GDCLASS(MeshGenerator, RefCounted)

	protected:
		static void _bind_methods();

	public:
		MeshGenerator();
		~MeshGenerator();
		static void extrude_polygon_along_path_arraymesh(
			const PackedVector2Array &polygon_2d,
			const PackedVector3Array &path_points,
			const Ref<ArrayMesh> &out_mesh

	);

	};

}

#endif#pragma once
