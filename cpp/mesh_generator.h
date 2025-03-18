#ifndef MESH_GENERATOR_H
#define MESH_GENERATOR_H

#include <godot_cpp/classes/ref.hpp>
#include <godot_cpp/classes/array_mesh.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/plane.hpp>
#include <godot_cpp/variant/transform3d.hpp>
#include <godot_cpp/classes/geometry2d.hpp>
#include <godot_cpp/core/class_db.hpp>

namespace godot {

class MeshGenerator : public RefCounted {
    GDCLASS(MeshGenerator, RefCounted);

protected:
    static void _bind_methods();

public:
    MeshGenerator() {}
    ~MeshGenerator() {}

    // Entry function matching GDScript signature:
    static void extrude_polygon_along_path_arraymesh(const PackedVector2Array &polygon_2d,
                                              const PackedVector3Array &path_points,
                                              const Ref<ArrayMesh> &out_mesh);

private:
    // Translated helper methods from GDScript:
    static PackedVector2Array compute_polygon_uvs(const PackedVector2Array &polygon);
    static Plane compute_triangle_tangent(const Vector3 &v0, const Vector3 &v1, const Vector3 &v2,
                                   const Vector2 &uv0, const Vector2 &uv1, const Vector2 &uv2);
    static PackedVector3Array calculate_normals_from_points(const PackedVector3Array &points);
    static void add_triangle(PackedVector3Array &vertex_array,
                      PackedVector3Array &normal_array,
                      PackedVector2Array &uv_array,
                      PackedInt32Array &index_array,
                      const Vector3 &v0, const Vector3 &n0, const Vector2 &uv0,
                      const Vector3 &v1, const Vector3 &n1, const Vector2 &uv1,
                      const Vector3 &v2, const Vector3 &n2, const Vector2 &uv2);

    static void build_end_caps(const PackedVector2Array &polygon_2d,
                        const PackedVector2Array &polygon_uvs,
                        const Array &transforms,
                        PackedVector3Array &vertex_array,
                        PackedVector3Array &normal_array,
                        PackedVector2Array &uv_array,
                        PackedInt32Array &index_array);

    static Array build_ring_transforms(const PackedVector3Array &path_points);

    static void set_the_arrays(const Ref<ArrayMesh> &mesh, const Array &arrays);
};

}

#endif
