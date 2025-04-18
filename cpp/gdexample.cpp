#include "gdexample.h"
#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void GDExample::_bind_methods() {
	ClassDB::bind_method(D_METHOD("get_amplitude"), &GDExample::get_amplitude);
	ClassDB::bind_method(D_METHOD("set_amplitude", "p_amplitude"), &GDExample::set_amplitude);

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "amplitude"), "set_amplitude", "get_amplitude");

}

GDExample::GDExample() {
	// Initialize any variables here.
	time_passed = 0.0;
}

GDExample::~GDExample() {
	// Add your cleanup here.
}

void GDExample::_process(double delta) {
	time_passed += delta * 2;
	
	Vector2 new_position = Vector2(
		amplitude + (amplitude * sin(time_passed * 2.0)),
		amplitude + (amplitude * cos(time_passed * 1.5))
	);
	Vector2 testStuff = Vector2(0,0);

	set_position(Vector2(0,0));
}



void GDExample::set_amplitude(const double p_amplitude) {
	amplitude = p_amplitude;
}

double GDExample::get_amplitude() const {
	return amplitude;
}