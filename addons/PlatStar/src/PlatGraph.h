//Object that stores the surfaces and edges of a platstar graph
//Stuctures/Edges are dictionaries because I don't know if we can add objects
#include <Godot.hpp>
#include <Resource.hpp>
#include <vector>
//#include <stack.h>

enum TravType {WALK, JUMP, FALL, JUMPPLAT, FALLPLAT};

using namespace godot;
struct Surface {
    int ind; //make sense to track this, for editor purposes
    Vector2 start;
    Vector2 end;

    Surface(int i, Vector2 s, Vector2 e): ind(i), start(s), end(e){}
};


struct Edge {
    TravType travType;
    int from;
    int to;
    //point ov exit and entrance is a linear interpolation of the start and end
    //point of relevant surface. Supposed to be calculated at search time
    //so that whenever we change the data of a surface, the position of an edge
    //implicitly changes with it.
    float exit;
    float entrance;

    Edge(int from, int to, float x, float n, TravType t = TravType::WALK) :
            from(from), travType(t), to(to), exit(x), entrance(n) {}
    Edge() : from(-1), to(-1), travType(TravType::WALK) {}
};

//custom ordinl operator
bool succDistVec2(Vector2 a, Vector2 b);

//translates the pointer to a node (to handle NULL instances to a dictionary)
Dictionary surf2Dict(Surface *s, int ind);

Dictionary edge2Dict(Edge *e);

namespace godot{

class PlatGraph : public Resource {
    GODOT_CLASS(PlatGraph, Resource)
private:
    /*
    As far as Godot is concerned
    Surface {
        start : Vector2, end : Vector2
    }
    Edge {
        from : int, to : int, type : TravType, exit : Vector2,
        entrance : Vector2
    }
    */

    //since the Engine's loader may try to set edges first
    bool loaded = false;


    //for cleaning and setting
    void deleteAllNodes();
    void deleteAllEdges();
    void deleteInvalidEdges();

public:
    int size = 0;
    std::vector<int> numEdges;
    std::vector<Surface*> surfaces;
    std::vector<std::vector<Edge*>> edges;
    //consider storing availble nodes and edges in a stack
    //faster but would be memory innefficient
    //wait actually don't use this at all, makes insertions complicated
    //std::stack<unsigned int> availableNodes
    //std::vector<std::stack<unsigned int>> availableEdges

    void _init();
    void emit_changed();
    //String get_class();
    //We can't use get_class if we want to be able to successfully load this
    //with Godots Resource loader for somereason
    bool is_class(String c);

    PlatGraph();
    ~PlatGraph();
    static void _register_methods();
    //public, but invisible to godot, i guess
    Array getNodes();
    Array getEdges();
    //slightly faster individual getter functions
    Dictionary getNode(const int);
    Dictionary getEdge(const int, const int);

    void setNodes(Array nodeArray);
    void setEdges(Array edgeArray);

    //probably bad practise to have it in this file but whatever
    //not-euclidian distance based closest
    Vector2 closestOnSurface(Vector2 p, const int s);
    Vector2 closestOnEdge(Vector2 p, const int ind, const int from);

    Vector2 getEdgeExit(Edge* ep);
    Vector2 getEdgeEntrance(Edge* ep);
    //because we want to able to add and remove surfaces and edges, we have to
    //give them indexes. but the indecies theselves may be hidden from godot
    void addNode(int ind, Vector2 start, Vector2 end);
    void connectNodes(int ind, int from, int to, float x, float n,
            TravType t = TravType::WALK);
    void connectNodesGD(int ind, int from, int to, float x, float n,
            int t = int(TravType::WALK));
    void removeNode(const int ind);
    void removeEdge(const int ind, const int from);

    int getAvailableNode();
    int getAvailableEdge(const int from);
    Variant closestPoint(Vector2 p);

    int closestSurface(Vector2 p);
    //vector that is [from ind] of edge whose straight line in the editor is
    std::vector<int> closestEdge(Vector2 p);


};
}
