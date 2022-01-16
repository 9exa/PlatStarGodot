#include <Godot.hpp>
#include <Resource.hpp>
#include <vector>

namespace godot{
class TestResource : public Resource {
    GODOT_CLASS(TestResource, Resource)
private :
    int a;
    String string;
    std::vector<int> v;
    void setV(Array a) {
        v.resize(a.size());
        for (int i = 0; i < a.size(); i++) {
            v[i] = a[i];
        }
    }
    Array getV() {
        Array a = Array();
        for (int i = 0; i < v.size(); i++) {

        }
        return a;
    }
public :
    void _init() {}
    static void _register_methods() {
        register_property<TestResource, int>("a", &TestResource::a, int());
        register_property<TestResource, Array>("v", &TestResource::setV, &TestResource::getV, Array());

    }
};
}
