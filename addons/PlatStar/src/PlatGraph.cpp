#include "PlatGraph.h"
#include <Math.hpp>
using namespace godot;
using Math::clamp;
//I refuse to import the standard library
static float min(float a, float b) {return (a>b)?b:a;}
static float max(float a, float b) {return (a<b)?b:a;}


Dictionary surf2Dict(Surface *s, int ind) {
    Dictionary out;
    out["start"] = s->start;
    out["end"] = s->end;
    out["ind"] = ind;
    return out;
}

Dictionary edge2Dict(Edge *e) {
    Dictionary out;
    out["from"] = e->from;
    out["to"] = e->to;
    out["travType"] = e->travType;
    out["exit"] = e->exit;
    out["entrance"] = e->entrance;
    return out;
}



const float SUCCMOD = 50;

//weighted towards minimizing x distance
bool succDistVec2(Vector2 a, Vector2 b) {
    float aval = a.x*a.x * SUCCMOD + a.y * a.y;
    float bval = b.x*b.x * SUCCMOD + b.y * b.y;
    return bval > aval;
}

void PlatGraph::_init() {}
//can't use this unfortunately

// String PlatGraph::get_class() {
//     return "PlatGraph";
// }

bool PlatGraph::is_class(String c) {
    return (c == String("PlatGraph")) || Resource::is_class(c);
}

void PlatGraph::emit_changed() {
    //the graph has been built, so all relevant checks for value itegrety apply
    loaded = true;
    Resource::emit_changed();
}

PlatGraph::PlatGraph() {
    size = 0;
}
//for cleanup just free all the nodes and edges
PlatGraph::~PlatGraph() {
    for (int i = 0; i < surfaces.size(); i++) {
        for (int j = 0; j < edges[i].size(); j++) {
            delete edges[i][j];
        }
        delete surfaces[i];
    }
    surfaces.clear();
    edges.clear();
}

void PlatGraph::_register_methods (){

    register_property<PlatGraph, Array>("surfaces", &PlatGraph::setNodes, &PlatGraph::getNodes, Array());
    register_property<PlatGraph, Array>("edges", &PlatGraph::setEdges, &PlatGraph::getEdges, Array());

    //register_method("_init", &PlatGraph::_init);
    //register_method("get_class", &PlatGraph::get_class);
    register_method("is_class", &PlatGraph::is_class);
    register_method("emit_changed", &PlatGraph::emit_changed);
    register_method("addNode", &PlatGraph::addNode);
    register_method("connectNodes", &PlatGraph::connectNodesGD);
    register_method("getAvailableNode", &PlatGraph::getAvailableNode);
    register_method("getAvailableEdge", &PlatGraph::getAvailableEdge);
    register_method("getNode", &PlatGraph::getNode);
    register_method("getEdge", &PlatGraph::getEdge);
    register_method("removeNode", &PlatGraph::removeNode);
    register_method("removeEdge", &PlatGraph::removeEdge);



}
Array PlatGraph::getNodes() {
    Array out;
    //copying technique from godot source code for max effeciency
    out.resize(surfaces.size());
    for (int i = 0; i < surfaces.size(); i++) {
        if (surfaces[i] != nullptr) {
            out[i] = (surf2Dict(surfaces[i], i));
        }
        else {
            out[i] = Variant();
        }
    }
    return out;
}
Array PlatGraph::getEdges() {
    Array out;
    //this ones slower because I can't be bothered to track number of edges
    for (int i =  0; i < edges.size(); i++) {
        Array innerOut;
        for (int j = 0; j < edges[i].size(); j++) {
            if (edges[i][j] != nullptr) {
                innerOut.append(edge2Dict(edges[i][j]));
            }
            else {
                innerOut.append(Variant());
            }
        }
        out.append(innerOut);
    }
    return out;
}

void PlatGraph::setNodes(Array nodeArray) {
    //expects array of dictionarys
    //ind, start, end
    for (int i = 0; i < nodeArray.size(); i++) {
        Dictionary dict = nodeArray[i];
        addNode(dict["ind"], dict["start"], dict["end"]);
    }
}
//as of now undefined
void PlatGraph::setEdges(Array edgeArray) {
    for (int f = 0; f < edgeArray.size(); f++) {
        Array inner = edgeArray[f];
        for (int i = 0; i < inner.size(); i++) {
            if (inner[i].get_type() != Variant::Type::NIL) {
                Dictionary dict = inner[i];
                connectNodesGD(i, dict["from"], dict["to"], dict["exit"],
                             dict["entrance"], dict["travType"]);
            }
        }
    }
    // Godot::print("Setting Edges success");
}

void PlatGraph::addNode(int ind, Vector2 start, Vector2 end) {
    //expand the array of nodes so it can hold that index

    if (surfaces.size() <= ind) {
        surfaces.resize(ind+1);
        edges.resize(ind+1);
        numEdges.resize(ind+1);
    }
    //fill empty ind
    if (surfaces[ind] == nullptr) {
        surfaces[ind] = new Surface(ind, start, end);
        size++;
    }
    //replace existing entry by changing values
    else {
        surfaces[ind]->start = start;
        surfaces[ind]->end = end;
    }
}

void PlatGraph::connectNodes(int ind, int from, int to, float x, float n,
        TravType t) {
    //don't add if there is no corresponding surface and the graphs has already
    //been loaded
    if (from >= surfaces.size() || to >= surfaces.size()) {
        if (loaded) { return; }
        else {
            //If graph yet to be loaded, add nulls is space of surfaces,
            //as engine will load them in soon
            int size = ((from < to) ? to : from) + 1;
            surfaces.resize(size);
            edges.resize(size);
            numEdges.resize(size);
        }
    }
    if (numEdges[from] <= ind) {
        edges[from].resize(ind+1);
        numEdges[from] = ind+1;
    }
    if (edges[from][ind] == nullptr) {
        edges[from][ind] = new Edge(from, to, x, n, t);
    }
    else {
        Edge* thing = edges[from][ind];
        thing->from = from;
        thing->to = to;
        thing->exit = x;
        thing->entrance = n;
        thing->travType = t;
    }
}

Dictionary PlatGraph::getNode(const int ind) {
    if (surfaces.size() > ind && surfaces[ind] != nullptr) {
        return surf2Dict(surfaces[ind], ind);
    }
    else { return Variant(); }
}
Dictionary PlatGraph::getEdge(const int ind, const int from) {
    if (edges.size() > from && edges[from].size() > ind && edges[from][ind] != nullptr) {
        return edge2Dict(edges[from][ind]);
    }
    else { return Variant(); }
}

void PlatGraph::connectNodesGD(int ind, int from, int to, float x, float n,
        int t) {
    connectNodes(ind, from, to, x, n, TravType(t));
}
//finds closest x position, then finds corresponding y position
Vector2 PlatGraph::closestOnSurface(Vector2 p, const int ind) {
    Surface s = *(surfaces[ind]);
    p.x = clamp(p.x, min(s.start.x, s.end.x), max(s.start.x, s.end.x));
    float m = (s.end.y - s.start.y) / (s.end.x - s.start.x);
    p.y = (p.x - s.start.x) * m + s.start.y;
    return p;
}

Vector2 PlatGraph::closestOnEdge(Vector2 p, const int ind,
                                 const int from) {
    //clamp p in case the normal is not in the bounds of the edge
    Vector2 exit = getEdgeExit(edges[from][ind]);
    Vector2 entrance = getEdgeEntrance(edges[from][ind]);
    float minx = min(exit.x, entrance.x);
    float maxx = max(exit.x, entrance.x);
    float miny = min(exit.y, entrance.y);
    float maxy = max(exit.y, entrance.y);
    p.x = clamp(p.x, minx, maxx);
    p.y = clamp(p.y, miny, maxy);
    //point is oon the line
    if (maxy == miny || minx == maxx) { return p; }
    //gradient and  normal
    float m = (maxy - miny) / (maxx - minx);
    float nm = -1 / m;
    //translation of x from start point
    float dx = (p.y - miny) / (m - nm);
    p.x = minx;
    p.y = miny + m * dx;
    return p;
}

Vector2 PlatGraph::getEdgeExit(Edge* ep) {
    Surface* daSurf = surfaces[ep->from];
    return Vector2::linear_interpolate(daSurf->start, daSurf->end, ep->exit);
}
Vector2 PlatGraph::getEdgeEntrance(Edge* ep) {
    Surface* daSurf = surfaces[ep->to];
    return Vector2::linear_interpolate(daSurf->start, daSurf->end, ep->entrance);
}

void PlatGraph::removeNode(const int ind) {
    //only do something if that node actually exists
    if (surfaces.size() > ind && surfaces[ind] != nullptr) {
        delete surfaces[ind];
        surfaces[ind] = nullptr;
        size -= 1;
        //get rid of all edges connected to that surface
        Edge* e;
        for (int f  = 0; f < surfaces.size(); f++) {
            for (int i = 0; i < edges[f].size(); i++) {
                e = edges[f][i];
                if (e != nullptr && (e->from == ind || e->to == ind)) {
                    removeEdge(i, f);
                }
            }
        }
    }
}

void PlatGraph::removeEdge(const int ind, const int from) {
    if (edges[from].size() > ind && edges[from][ind] != nullptr) {
        delete edges[from][ind];
        edges[from][ind] = nullptr;
        numEdges[from] -= 1;
    }
}

int PlatGraph::getAvailableNode() {
    //only bother looking through array if we know they aren't full
    if (size < surfaces.size()) {
        for (int i = 0; i < surfaces.size(); i++) {
            if (surfaces[i] == nullptr) { return i; }
        }
        /*stack implementation
        return availableNodes.pop();
        */
    }
    return size;
}

int PlatGraph::getAvailableEdge(const int from) {
    //only bother looking through array if we know they aren't full
    if (numEdges[from] < edges[from].size()) {
        for (int i = 0; i < surfaces.size(); i++) {
            if (edges[from][i] == nullptr) { return i; }
        }
    }
    return numEdges[from];
}
Variant PlatGraph::closestPoint(Vector2 p) {
    if (size == 0) {
        return Variant();
    }
    else {
        int s = closestSurface(p);
        return closestOnSurface(p, s);
    }
}

int PlatGraph::closestSurface(Vector2 p) {
    if (size == 0) { return -1; }
    int out = -1;
    Vector2 outDiff;
    for (int i = 0; i < surfaces.size(); i++) {
        if (surfaces[i] != nullptr) {
            Vector2 candDiff = closestOnSurface(p, i) - p;
            if (out == -1 || succDistVec2(candDiff, outDiff)) {
                out = i;
                outDiff = candDiff;
            }
        }
    }
    return out;
}

//unlike for nodes, returns coords, also unweighted distance, not that it would matter
std::vector<int> PlatGraph::closestEdge(Vector2 p) {
    std::vector<int> out = {-1,-1};
    if (size == 0) { return out; }
    Vector2 outDiff;
    for (int i = 0; i < edges.size(); i++) {
        for (int j = 0; j < edges[i].size(); j++) {
            if (edges[i][j] != nullptr) {
                Vector2 candDiff = closestOnEdge(p, j, i) - p;
                if (out[0] == -1 ||
                        outDiff.length_squared() > candDiff.length_squared()) {
                    out[0] = i; out[1] = j;
                    outDiff = candDiff;
                }
            }
        }
    }
    return out;
}
