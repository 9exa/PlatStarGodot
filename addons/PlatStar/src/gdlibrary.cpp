#include "PlatStar.h"
//#include "TestResource.cpp"
//just copy the origional one for now
extern "C" void GDN_EXPORT godot_gdnative_init(godot_gdnative_init_options *o) {
    godot::Godot::gdnative_init(o);
}

extern "C" void GDN_EXPORT godot_gdnative_terminate(godot_gdnative_terminate_options *o) {
    godot::Godot::gdnative_terminate(o);
}

extern "C" void GDN_EXPORT godot_nativescript_init(void *handle) {
    godot::Godot::nativescript_init(handle);
    godot::register_class<godot::PlatStar>();
    //using gdnative as a tool crashes the editor for some reason.
    godot::register_class<godot::PlatGraph>();
    //godot::register_class<godot::TestResource>();
}
