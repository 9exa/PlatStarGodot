#ifndef PLATSTAR
#define PLATSTAR
//#include <vector>
//#include <string>
#include <queue>
#include <vector>
#include <Godot.hpp>
#include <Reference.hpp>
#include <Engine.hpp>
#include "PlatGraph.h"
//Godot integrated implementation of PlayStar
//Astar-like path finding agorithm in c++ for use in a 2D platformer
//We'll have to import it into Godot Later

using namespace godot;
//we'll have to wrie this twice in the plugin
// enum TravType {WALK, JUMP, FALL};
// TravType travTypeFromString(const char* string);
// //arrays are weird don't be stupid use a struct
//
// struct Surface {
//     Vector2 start;
//     Vector2 end;
//
//     Surface(Vector2 s, Vector2 e): start(s), end(e){}
// };
//
// struct Edge {
//     TravType travType;
//     unsigned int from;
//     unsigned int to;
//     Vector2 exit;
//     Vector2 entrance;
//
//     Edge(int from, int to, Vector2 x, Vector2 n, TravType t = TravType::WALK) :
//             from(from), travType(t), to(to), exit(x), entrance(n) {}
//     Edge() : from(-1), to(-1), travType(TravType::WALK) {}
// };

//arranged into output
struct PathStep {
    TravType travType;
    Vector2 to;
    PathStep *next;
    PathStep(Vector2 to, TravType travType = TravType::WALK, PathStep *next = NULL)
            : to(to), travType(travType), next(next){}
};
void freePathSteps(PathStep* head);
/*
//arbitrary objects to help with serializing the handles of lines in gui
struct NodeHandle {
    //enum  {NODE, EDGE};
    enum {START = 0, END = 1};

    int size = 0;
    std::vector<int> sides;
    std::vector<Surface*> surfs;

    NodeHandle(std::vector<Surface*> surfs, std::vector<int> sides) :
            surfs(surfs), sides(sides), size(surfs.size()) {}
};
*/
namespace godot {
//Object that does the pathfinding heavy lifting
//must be access through another nodes api
class PlatStar : public Reference {
    GODOT_CLASS(PlatStar, Reference)
private :
    //The heuristic between of traveling to node next
    float heuristic(PlatGraph*, Edge* e, Vector2 target);
    float calcCost(PlatGraph*, Edge* e, Vector2 from);
    //search and related helper functions
    struct EdgeCost {
        float cost;
        float heuristic;
        Edge* edge;
        EdgeCost(float c, float h, Edge* e) : cost(c), heuristic(h), edge(e) {}
        EdgeCost() : cost(0), heuristic(0), edge(nullptr) {}
    };
    static bool edgeCostLess(EdgeCost a, EdgeCost b);
    typedef std::priority_queue<EdgeCost, std::vector<EdgeCost>,
                                        decltype(&edgeCostLess)>
            edgeCostQueue;
    //main search function:
    PathStep* findPath(PlatGraph*, Vector2, Vector2, const float);
    int closestVisited(PlatGraph*, Vector2, bool*);
    void queueNewEdges(PlatGraph*, unsigned int, Vector2, Vector2, float, edgeCostQueue*);
    EdgeCost getNextEdge(PlatGraph*, bool*, float, edgeCostQueue*);
    PathStep* backtrack(PlatGraph*, Vector2, Vector2, unsigned int, unsigned int, Edge**);
    PathStep* toNextNode(PlatGraph*, unsigned int from, Vector2 target);

    unsigned int size;

    //std::vector<Handle> edgeHandes;
    //std::vector<NodeHandle> nodeHandles;

    //PlatGraph* graph;

public :
    static void _register_methods();
    String get_class();
    PlatStar();
    ~PlatStar();
    //we need one in order to instance it. even if it doesn't do anything
    void _init();
    /*
    //I have NOOOOO idea how we're gonna remove nodes
    void addNodeToGraph(int ind, Vector2 start, Vector2 end);
    void connectNodes(unsigned int n1, unsigned int n2,
            float exit, float entrance, TravType type);
    //version that doesn't use enums for godot compilation
    void _connectNodes(unsigned int n1, unsigned int n2,
            float exit, float entrance, int type) {
                connectNodes(n1, n2, exit, entrance, TravType(type));
            }

    //godot itself cannot select an edge, so insetead, for deletions we
    //give platStar a region and tell it to delete everything in that region
    //kind of like an erase
    void deleteEdgeAround(Vector2 p, float r);
    void deleteNodeAround(Vector2 p, float r);

    //for changing the values of a node/end we serialize all intersections as
    //handles. The engine tells us that this handle moves here and the actual
    //changeing of surface/edge values happens in platstar.
    int getNodeHandle(Vector2 p, float r);
    void setNodeHandle(int handHash, Vector2 position);
    Vector2 nodeHandlePos(NodeHandle h);



    int getEdgeHandle(Vector2 p, float r);
    void setEdgeHandle(int handHash, Vector2 position);
    */


    //public search function
    Array query(PlatGraph*, Vector2, Vector2, const float jumpheight);

    void loadDict(Dictionary);
};

}
#endif
