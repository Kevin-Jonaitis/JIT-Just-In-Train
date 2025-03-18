#include "mesh_generator.h"
#include <godot_cpp/core/class_db.hpp>

#include <godot_cpp/classes/mesh.hpp>
#include <godot_cpp/variant/transform3d.hpp>
#include <godot_cpp/classes/geometry2d.hpp>
#include <godot_cpp/classes/mesh.hpp>
#include <godot_cpp/variant/utility_functions.hpp> // for printing, etc.

using namespace godot;

void MeshGenerator::_bind_methods() {
    // ClassDB::bind_method(D_METHOD("extrude_polygon_along_path_arraymesh",
    //                               "polygon_2d", "path_points", "out_mesh"),
    //                      &MeshGenerator::extrude_polygon_along_path_arraymesh);

	ClassDB::bind_static_method("MeshGenerator", D_METHOD("extrude_polygon_along_path_arraymesh", "polygon_2d", "path_points", "out_mesh"), 
    &MeshGenerator::extrude_polygon_along_path_arraymesh);
    // Bind other helper methods if you want to expose them to scripts.
}

// -----------------------------------------------------------------------------
// Translated GDScript -> C++ helper methods
// -----------------------------------------------------------------------------

PackedVector2Array MeshGenerator::compute_polygon_uvs(const PackedVector2Array &polygon) {
    PackedVector2Array uvs;
    int count = polygon.size();
    if (count < 2) {
        return uvs;
    }

    real_t total_length = 0.0;
    for (int i = 0; i < count; i++) {
        int next_i = (i + 1) % count;
        total_length += polygon[i].distance_to(polygon[next_i]);
    }

    real_t cum_length = 0.0;
    for (int i = 0; i < count; i++) {
        if (i > 0) {
            cum_length += polygon[i - 1].distance_to(polygon[i]);
        }
        Vector2 uv(0.0, cum_length);
        uvs.push_back(uv);
    }

    // Duplicate first with v = total_length to close loop
    uvs.push_back(Vector2(0.0, total_length));

    return uvs;
}

Plane MeshGenerator::compute_triangle_tangent(const Vector3 &v0, const Vector3 &v1, const Vector3 &v2,
                                              const Vector2 &uv0, const Vector2 &uv1, const Vector2 &uv2) {
    Vector3 edge1 = v1 - v0;
    Vector3 edge2 = v2 - v0;
    Vector2 deltaUV1 = uv1 - uv0;
    Vector2 deltaUV2 = uv2 - uv0;

    real_t det = deltaUV1.x * deltaUV2.y - deltaUV1.y * deltaUV2.x;
    real_t r = (Math::abs(det) > 0.0001) ? (1.0 / det) : 1.0;

    Vector3 tangent = (edge1 * deltaUV2.y - edge2 * deltaUV1.y) * r;
    tangent = tangent.normalized();

    // The tangent is stored as Vector4 in GDScript (Plane is often used as Vector4).
    // We'll store tangent.x, tangent.y, tangent.z, and w=1.0
    Plane plane_tangent(tangent.x, tangent.y, tangent.z, 1.0);
    return plane_tangent;
}

PackedVector3Array MeshGenerator::calculate_normals_from_points(const PackedVector3Array &points) {
    PackedVector3Array normals;
    int size = points.size();
    if (size < 2) {
        return normals;
    }

    for (int i = 0; i < size - 1; i++) {
        Vector3 direction = points[i + 1] - points[i];
        // direction.cross(Vector3::UP).normalized(); // This line in GDScript is a no-op
        Vector3 normal = Vector3(-direction.z, 0, direction.x).normalized();
        normals.push_back(normal);
    }

    // Add the last normal
    if (size > 1) {
        Vector3 last_direction = points[size - 1] - points[size - 2];
        // last_direction.cross(Vector3::UP).normalized();
        Vector3 last_normal = Vector3(-last_direction.z, 0, last_direction.x).normalized();
        normals.push_back(last_normal);
    }

    return normals;
}

void MeshGenerator::add_triangle(PackedVector3Array &vertex_array,
                                 PackedVector3Array &normal_array,
                                 PackedVector2Array &uv_array,
                                 PackedInt32Array &index_array,
                                 const Vector3 &v0, const Vector3 &n0, const Vector2 &uv0,
                                 const Vector3 &v1, const Vector3 &n1, const Vector2 &uv1,
                                 const Vector3 &v2, const Vector3 &n2, const Vector2 &uv2) {
    int base_index = vertex_array.size();

    vertex_array.push_back(v0);
    normal_array.push_back(n0);
    uv_array.push_back(uv0);

    vertex_array.push_back(v1);
    normal_array.push_back(n1);
    uv_array.push_back(uv1);

    vertex_array.push_back(v2);
    normal_array.push_back(n2);
    uv_array.push_back(uv2);

    index_array.push_back(base_index);
    index_array.push_back(base_index + 1);
    index_array.push_back(base_index + 2);
}

void MeshGenerator::build_end_caps(const PackedVector2Array &polygon_2d,
                                   const PackedVector2Array &polygon_uvs,
                                   const Array &transforms,
                                   PackedVector3Array &vertex_array,
                                   PackedVector3Array &normal_array,
                                   PackedVector2Array &uv_array,
                                   PackedInt32Array &index_array) {
    // Triangulate
	
    PackedInt32Array poly_indices = Geometry2D::get_singleton()->triangulate_polygon(polygon_2d);
    if (poly_indices.size() < 3) {
        return;
    }

    // Compute bounding box for the polygon (used for face_uvs)
    real_t min_x = polygon_2d[0].x;
    real_t max_x = min_x;
    real_t min_y = polygon_2d[0].y;
    real_t max_y = min_y;
    for (int i = 0; i < polygon_2d.size(); i++) {
        Vector2 pt = polygon_2d[i];
        if (pt.x < min_x) min_x = pt.x;
        if (pt.x > max_x) max_x = pt.x;
        if (pt.y < min_y) min_y = pt.y;
        if (pt.y > max_y) max_y = pt.y;
    }

    // Build face_uvs (this example offsets by max_x and max_y similarly to GDScript)
    Vector<Vector2> face_uvs;
    face_uvs.resize(polygon_2d.size());
    for (int i = 0; i < polygon_2d.size(); i++) {
        Vector2 pt = polygon_2d[i];
        real_t u_offset = pt.x - max_x;
        real_t v_offset = pt.y - max_y;
        face_uvs.set(i, Vector2(u_offset, v_offset));
    }

    // FRONT CAP
    Transform3D front_transform = transforms[0];
    Vector<Vector3> front_vertices;
    front_vertices.resize(polygon_2d.size());
	// print_line("front_transform: " + String(front_transform));
    for (int i = 0; i < polygon_2d.size(); i++) {
        Vector2 v2 = polygon_2d[i];
        front_vertices.set(i, front_transform.xform(Vector3(v2.x, v2.y, 0.0)));
    }
	// for (int i = 0; i < front_vertices.size(); i++) {
	// 	print_line("front_vertices[" + String::num_int64(i) + "]: " + String(front_vertices[i]));
	// }

    for (int i = 0; i < poly_indices.size(); i += 3) {
        int idx0 = poly_indices[i + 0];
        int idx1 = poly_indices[i + 1];
        int idx2 = poly_indices[i + 2];

        Vector3 vA = front_vertices[idx0];
        Vector3 vB = front_vertices[idx1];
        Vector3 vC = front_vertices[idx2];

        Vector2 uvA = face_uvs[idx0];
        Vector2 uvB = face_uvs[idx1];
        Vector2 uvC = face_uvs[idx2];

        Vector3 normal = (vC - vA).cross(vB - vA).normalized();

        add_triangle(vertex_array, normal_array, uv_array, index_array,
                     vA, normal, uvA,
                     vB, normal, uvB,
                     vC, normal, uvC);
    }

    // BACK CAP (inverted so that normals face outward)
    Transform3D back_transform = transforms[transforms.size() - 1];
    Vector<Vector3> back_vertices;
    back_vertices.resize(polygon_2d.size());
    for (int i = 0; i < polygon_2d.size(); i++) {
        Vector2 v2 = polygon_2d[i];
        back_vertices.set(i, back_transform.xform(Vector3(v2.x, v2.y, 0.0)));
    }

    for (int i = 0; i < poly_indices.size(); i += 3) {
        int idx0 = poly_indices[i + 0];
        int idx1 = poly_indices[i + 1];
        int idx2 = poly_indices[i + 2];

        // Invert the winding: (idx2, idx1, idx0)
        Vector3 vA = back_vertices[idx2];
        Vector3 vB = back_vertices[idx1];
        Vector3 vC = back_vertices[idx0];

        Vector2 uvA = face_uvs[idx2];
        Vector2 uvB = face_uvs[idx1];
        Vector2 uvC = face_uvs[idx0];

        Vector3 normal = (vC - vA).cross(vB - vA).normalized();

        add_triangle(vertex_array, normal_array, uv_array, index_array,
                     vA, normal, uvA,
                     vB, normal, uvB,
                     vC, normal, uvC);
    }
}

Array MeshGenerator::build_ring_transforms(const PackedVector3Array &path_points) {
    Array transforms;
    int size = path_points.size();
    if (size < 2) {
        return transforms;
    }

    for (int i = 0; i < size; i++) {
        Transform3D face_transform;
		// Identity
        face_transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0);

        if (i == 0 && size > 1) {
            Vector3 direction = path_points[1] - path_points[0];
            face_transform = face_transform.looking_at(direction, Vector3(0, 1, 0), true);
            face_transform = face_transform.translated(path_points[i]);
        } else if (i < size - 1) {
            Vector3 prev_dir = path_points[i] - path_points[i - 1];
            Vector3 next_dir = path_points[i + 1] - path_points[i];
            Vector3 direction2 = prev_dir + next_dir;
            face_transform = face_transform.looking_at(direction2, Vector3(0, 1, 0), true);
            face_transform = face_transform.translated(path_points[i]);
        } else if (i == size - 1) {
            Vector3 direction_last = path_points[i] - path_points[i - 1];
            face_transform = face_transform.looking_at(direction_last, Vector3(0, 1, 0), true);
            face_transform = face_transform.translated(path_points[i]);
        }

        transforms.push_back(face_transform);
    }

    return transforms;
}

void MeshGenerator::set_the_arrays(const Ref<ArrayMesh> &mesh, const Array &arrays) {
    // This adds a surface with PRIMITIVE_TRIANGLES using the arrays provided.
    mesh->add_surface_from_arrays(Mesh::PRIMITIVE_TRIANGLES, arrays);
}

// -----------------------------------------------------------------------------
// MAIN FUNCTION (Entry point) 
// -----------------------------------------------------------------------------
void MeshGenerator::extrude_polygon_along_path_arraymesh(const PackedVector2Array &polygon_2d,
                                                         const PackedVector3Array &path_points,
                                                         const Ref<ArrayMesh> &out_mesh) {
    // 1) Precompute polygon UVs
    PackedVector2Array polygon_uvs = compute_polygon_uvs(polygon_2d);

    // 2) Compute cumulative distances (for potential UV logic)
    real_t total_length = 0.0;
    Vector<real_t> cumulative_dist;
    cumulative_dist.push_back(0.0); // start at 0
    for (int i = 1; i < path_points.size(); i++) {
        total_length += path_points[i - 1].distance_to(path_points[i]);
        cumulative_dist.push_back(total_length);
    }

    // 3) Build ring transforms
    Array transforms = build_ring_transforms(path_points);
	// print_line("CPP transforms");
	// for (int i = 0; i < transforms.size(); i++) {
	// print_line("transforms[" + String::num_int64(0) + "]: " + String(transforms[0]));
	// }

    // 4) Prepare arrays (unindexed)
    PackedVector3Array vertex_array;
    PackedVector3Array normal_array;
    PackedVector2Array uv_array;
    PackedInt32Array index_array;

    // We replicate logic from GDScript
    Vector<Vector3> prev_global_points;
    Vector<Vector3> current_global_points;

    Vector3 vA, vB, vC, vD;
    Vector2 vA_uv, vB_uv, vC_uv, vD_uv;

    Vector3 previous_simplify_dir = Vector3(0, 0, 0);
    const real_t ANGLE_DIFF = 0.0872665; // ~5 degrees in radians
    real_t angle_simplify_dot = Math::cos(ANGLE_DIFF);

    int previous_ring_i = 0;

    // Build side walls
    for (int ring_i = 0; ring_i < transforms.size(); ring_i++) {
        Transform3D t = transforms[ring_i];
        current_global_points.clear();

        // Convert each 2D vertex using transform
        int poly_count = polygon_2d.size();
        for (int j = 0; j < poly_count; j++) {
            Vector2 v2 = polygon_2d[j];
            Vector3 global_pt = t.xform(Vector3(v2.x, v2.y, 0.0));
            current_global_points.push_back(global_pt);
        }
        // Duplicate the first vertex to "close" the ring
        current_global_points.push_back(current_global_points[0]);

        if (ring_i > 0) {
            // Check if we skip this ring due to small angle
            Vector3 prev_point = ((Transform3D)transforms[ring_i - 1]).origin;
            Vector3 curr_point = ((Transform3D)transforms[ring_i]).origin;
            Vector3 current_extrusion_dir = (curr_point - prev_point).normalized();

            if (ANGLE_DIFF > 0.0 && ring_i > 1 && ring_i != (transforms.size() - 1)
                && previous_simplify_dir.dot(current_extrusion_dir) > angle_simplify_dot) {
                // Skip adding side faces for this ring
                continue;
            } else {
                previous_simplify_dir = current_extrusion_dir;
            }

            // Build side quads
            int ring_size = poly_count + 1;
            for (int j = 0; j < ring_size; j++) {
                int j_next = (j + 1) % ring_size;

                vA = prev_global_points[j];
                vB = prev_global_points[j_next];
                vC = current_global_points[j_next];
                vD = current_global_points[j];

                // Example UV logic (u from cumulative_dist, v from polygon_uvs)
                real_t u_prev = cumulative_dist[previous_ring_i];
                real_t u_next = cumulative_dist[ring_i];

                // Bound-check polygon_uvs
                // (j or j_next can be up to polygon_2d.size(), so we do modulo or clamp)
                int uv_j      = (j      < polygon_uvs.size()) ? j      : (polygon_uvs.size() - 1);
                int uv_j_next = (j_next < polygon_uvs.size()) ? j_next : (polygon_uvs.size() - 1);

                Vector2 v_prev_uv = polygon_uvs[uv_j];
                Vector2 v_next_uv = polygon_uvs[uv_j_next];

                vA_uv = Vector2(1.0f - u_prev, v_prev_uv.y);
                vB_uv = Vector2(1.0f - u_prev, v_next_uv.y);
                vC_uv = Vector2(1.0f - u_next, v_next_uv.y);
                vD_uv = Vector2(1.0f - u_next, v_prev_uv.y);

                // Triangle 1: (vA, vB, vC)
                Vector3 normal1 = (vC - vA).cross(vB - vA).normalized();
                add_triangle(vertex_array, normal_array, uv_array, index_array,
                             vA, normal1, vA_uv,
                             vB, normal1, vB_uv,
                             vC, normal1, vC_uv);

                // Triangle 2: (vC, vD, vA)
                Vector3 normal2 = (vA - vC).cross(vD - vC).normalized();
                add_triangle(vertex_array, normal_array, uv_array, index_array,
                             vC, normal2, vC_uv,
                             vD, normal2, vD_uv,
                             vA, normal2, vA_uv);
            }
            previous_ring_i = ring_i;
        }

        // Copy current_global_points -> prev_global_points
        prev_global_points = current_global_points;
    }

    // Build end caps
    build_end_caps(polygon_2d, polygon_uvs, transforms,
                   vertex_array, normal_array, uv_array, index_array);

    // Create the final array for add_surface_from_arrays
    Array arrays;
    arrays.resize(Mesh::ARRAY_MAX);
    arrays[Mesh::ARRAY_VERTEX] = vertex_array;
    arrays[Mesh::ARRAY_NORMAL] = normal_array;
    arrays[Mesh::ARRAY_TEX_UV] = uv_array;
    arrays[Mesh::ARRAY_INDEX] = index_array;

    // Place arrays into out_mesh
    set_the_arrays(out_mesh, arrays);
}
