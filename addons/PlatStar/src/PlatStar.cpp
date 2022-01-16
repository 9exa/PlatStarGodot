#include "PlatStar.h"

using namespace godot;

void freePathSteps(PathStep* head) {
    while (head != nullptr) {
        PathStep* next = head->next;
        delete head;
        head = next;
    }
}

PlatStar::PlatStar() {
}

PlatStar::~PlatStar() {
}

String PlatStar::get_class() { return "PlatStar"; }

void PlatStar::_init() {
    size = 0;
}

void PlatStar::_register_methods() {
    register_method("get_class", &PlatStar::get_class);
    register_method("_init", &PlatStar::_init);
    register_method("query", &PlatStar::query);
}
/*
Variant PlatStar::graphData() {
    if (graph == nullptr) {
        return Variant();
    }
    else {
        Dictionary out = Dictionary();
        out[nodes] = graph->getNodes();
        out[edges] = graph->getEdges();
    }
}
*/


//just retrun the square distance of target to the closest point in
//the node indexed at to
float PlatStar::heuristic(PlatGraph* graph, Edge* e, Vector2 target) {
    int nextNode = e->to;
    return (graph->closestOnSurface(target, nextNode) - target).length();
}
//sum of distance of walking to edge and
float PlatStar::calcCost(PlatGraph* graph, Edge* e, Vector2 from) {
    Vector2 exitPos = graph->getEdgeExit(e);
    Vector2 entrancePos = graph->getEdgeEntrance(e);
    return ((exitPos - from).length()
        + (entrancePos - exitPos).length());
}

bool PlatStar::edgeCostLess(const EdgeCost a, const EdgeCost b)
        {return (a.cost + a.heuristic > b.cost + b.heuristic);}

//return visited surface closest to point
int PlatStar::closestVisited(PlatGraph* graph, Vector2 target,
                                      bool* visited) {
    int out;
    float candDist = -1.0;
    for (int i = 0; i < graph->surfaces.size(); i++) {
        if (visited[i] == true && graph->surfaces[i] != nullptr) {
            Vector2 nP = graph->closestOnSurface(target, i);
            float newDist = (target - nP).length_squared();
            if (newDist < candDist || candDist < 0) {
                out = i;
                candDist = newDist;
            }
        }
    }
    return out;
}


//Actual bfs search step
//crashes with empty graph lmoa
PathStep* PlatStar::findPath(PlatGraph* graph, Vector2 source, Vector2 target,
                             float jumpheight) {
    //find the corresponding starting and target surfaces
    int startNode = graph->closestSurface(source);
    int endNode = graph->closestSurface(target);
    //edit the sourc and the target point so they lie on a surface
    source = graph->closestOnSurface(source, startNode);
    target = graph->closestOnSurface(target, endNode);
    //keep track of where we've been and how we got there
    //Edge *previous[size] = {NULL};
    Edge** previous = new Edge*[graph->surfaces.size()]();
    //bool visited[size] = {false};
    bool* visited = new bool[graph->surfaces.size()]();
    //priority queue for uniform cost search
    edgeCostQueue prioQ(edgeCostLess);

    //unit has to walk from entrance of one edge to exit of another
    //which is taken into account in calculating cost.
    Vector2 *startPoints = new Vector2[graph->surfaces.size()]();
    startPoints[startNode] = source;
    visited[startNode] = true;

    //track newest surface and do int main search loop
    int newNode = startNode;
    unsigned int loopcount = 0;
    //std::cout<< "From: " << newNode << " trying to get to " << endNode << '\n';
    float lastCost = 0;
    while (endNode != newNode) {

        //add all new edges to  the queue
        queueNewEdges(graph, newNode, startPoints[newNode], target, lastCost, &prioQ);
        //Get the next available surface
        EdgeCost stepCost = getNextEdge(graph, visited, jumpheight, &prioQ);
        lastCost = stepCost.cost;
        Edge* nextEdge = stepCost.edge;
        //no path found; output what we have so far instead
        if (nextEdge == nullptr) {
            //get the explored edge clossest to the target
            endNode = closestVisited(graph, target, visited);
            target = graph->closestOnSurface(target, endNode);
            break;
        }
        //set new current node and point and repeat
        visited[newNode] = true;
        newNode = nextEdge->to;
        startPoints[newNode] = graph->getEdgeExit(nextEdge);
        previous[newNode] = nextEdge;
        loopcount++;

    }

    //backtrack through sequence of nodes used to get to target
    PathStep *out = backtrack(graph, source, target, startNode,
                              endNode, previous);
    delete previous;//don't forget cleanup
    delete visited;
    delete startPoints;

    return out;
}

void PlatStar::queueNewEdges(PlatGraph* graph, unsigned int newNode,
                            Vector2 startPoint, Vector2 target, float prevCost,
                            edgeCostQueue* prioQp) {
    for (int i = 0; i < graph->edges[newNode].size(); i++) {
        //edge untravelable if too high above current surface
        //again - is up
        Edge* candE = (graph->edges[newNode][i]);
        if (candE != nullptr) {
            float cost = calcCost(graph, candE, startPoint) + prevCost;
            float h = heuristic(graph, candE, target);
            //add the edge to the queue with the cost as the weight
            EdgeCost ec = EdgeCost(cost, h, candE);
            prioQp->push(ec);
        }
    }
}
PlatStar::EdgeCost PlatStar::getNextEdge(PlatGraph* graph, bool* visited, float jumpheight,
                            edgeCostQueue* prioQp) {
    bool cond;
    EdgeCost step;
    do {
        //failCase: platform unreachable
        //implement later: backtrack from currently closest discoverd node.
        if (prioQp->empty()) {return EdgeCost();}

        step = prioQp->top();
        prioQp->pop();
        Edge* nextEdge = step.edge;
        //cannot go to an already visited node,
        //cannot go to a platform thar is too high to jump to (- is up)
        float exity = graph->getEdgeExit(nextEdge).y;
        float entrancey = graph->getEdgeEntrance(nextEdge).y;
        cond = (visited[nextEdge->to] == false &&
                (exity - entrancey) >= -jumpheight);
    } while(!cond);
    return step;
}
PathStep* PlatStar::backtrack(PlatGraph* graph,
                    Vector2 startPoint, Vector2 endPoint,
                    unsigned int startNode, unsigned int endNode,
                    Edge **previous) {
    PathStep* out = new PathStep(endPoint, TravType::WALK, NULL);
    unsigned int newNode = endNode;
    Vector2 lastAt = endPoint;
    while (newNode != startNode) {
        //push front the last 2 steps of getting to current surface/node
        Edge* theEdge = previous[newNode];

        //iterate back. not done at back of loop so we only have to assign once
        newNode = theEdge->from;
        lastAt = graph->getEdgeEntrance(theEdge);
        //no need do add to things when walking to adjacent surfaces
        if (theEdge->travType != TravType::WALK) {
            out = new PathStep(lastAt, theEdge->travType, out);
        }
        out = new PathStep(graph->getEdgeExit(theEdge), TravType::WALK, out);

    }
    //finally add walking to "source", in case it was changed in findPath
    return new PathStep(startPoint, TravType::WALK, out);
}

/*
//wrapper for platgraph functions mostly
void PlatStar::addNodeToGraph(int ind, Vector2 start, Vector2 end) {
    size++;
    graph->addNode(ind, start, end);
    std::vector<Surface*> surfs = {graph->surfaces[ind]};
    std::vector<int> startSides(NodeHandle::START);
    std::vector<int> endSides(NodeHandle::END);
    //add the start and end handles
    nodeHandles.push_back(NodeHandle(surfs, startSides));
    nodeHandles.push_back(NodeHandle(surfs, endSides));
}
//godot is not supposed to lable edges/know indicies of edges. So all of that
//has to happen here
void PlatStar::connectNodes(unsigned int from, unsigned int to,
        float exit, float entrance, TravType type) {
    if (from >= size || to >= size) {
        Godot::print("graph too small, edge not added");
        return;
    }
    int ind = graph->getAvailableEdge(from);
    graph->connectNodes(ind, from, to, exit, entrance, type);
}
//finds nearest edge/surface in graph and removes them
//like eraser function in editor
void PlatStar::deleteEdgeAround(Vector2 p, float r) {
    std::vector<int> ei = graph->closestEdge(p);
    //no edge found
    if (ei[0] == -1) { return; }
    Vector2 pointOnEdge = graph->closestOnEdge(p, ei[1], ei[0]);
    float dist2 = (pointOnEdge - p).length_squared();
    if (dist2 < r*r) {
        graph->removeEdge(ei[1], ei[0]);
    }
}
void PlatStar::deleteNodeAround(Vector2 p, float r) {
    int n1 = graph->closestSurface(p);
    if (n1 == -1) { return; }
    Vector2 pointOnEdge = graph->closestOnSurface(p, n1);
    float dist2 = (pointOnEdge - p).length_squared();
    if (dist2 < r*r) {
        graph->removeNode(n1);
        size -= 1;
    }
}

//abstract classes to assist in gui stuff
//get the closest node handle within a radius, if any
int PlatStar::getNodeHandle(Vector2 p, float r) {
    for (int i = 0; i < nodeHandles.size(); i++) {
        Vector2 pos = nodeHandlePos(nodeHandles[i]);
        float dist2 = (pos-p).length_squared();
        if (dist2 < r*r) {
            return i;
        }
    }
    return -1;
}
void PlatStar::setNodeHandle(int handHash, Vector2 position) {
    NodeHandle theHandle = nodeHandles[handHash];
    for (int i =0; i < theHandle.size; i++) {
        Surface* sp = theHandle.surfs[i];
        if (theHandle.sides[i] == NodeHandle::START) {
            sp->start = position;
        }
        else {
            sp->end = position;
        }
    }
}

//int PlatStar::getEdgeHandle(Vector2 p, float r);
//void PlatStar::setEdgeHandle(int handHash, Vector2 position);

Vector2 PlatStar::nodeHandlePos(NodeHandle h) {
    Surface theSurface = *(h.surfs[0]);
    if (h.sides[0] == NodeHandle::START) { return theSurface.start; }
    else { return theSurface.end; }
}
*/
Array PlatStar::query(PlatGraph* graph, Vector2 source, Vector2 target,
                      const float jumpheight) {
    if (graph->size == 0) { return Array(); }
    Array out = Array();
    PathStep* result = nullptr;

    result = findPath(graph, source, target, jumpheight);
    for (PathStep* curr = result; curr != nullptr; curr = curr->next){
        out.append(Array::make(int(curr->travType), curr->to));
    }

    freePathSteps(result);
    return out;
}
