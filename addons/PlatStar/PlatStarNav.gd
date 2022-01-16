tool
extends Node2D


func get_class(): return "PlatStarNav"
#interface for setting up -and querying- platstar graph search

const PlatGraph = preload("PlatGraph.gdns")

const NODECOL = Color.blue
const NODECOLLIGHT = Color.cadetblue
const EDGECOL = Color.orange
const EDGECOLLIGHT = Color.bisque
#which type is seelected, if any
enum {NONE, NODE, EDGE}
const LINEWIDTH = 3
const ARROWSIZE = 15
#const PlatGraph = preload("res://addons/PlatStar/PlatGraph.gdns")

#the travtypes that a node has, must match PlatGraph.cpp
enum {WALK, JUMP, FALL}
const TypeString = ["WALK", "JUMP", "FALL"]
const DEFJUMPHEIGHT := 200.0

#the platgraph
var platStar : Reference
export (Resource) var graph
var font
var queueRedraw : bool = false


func _ready():
	if graph == null:
		graph = PlatGraph.new()
	elif graph is Object:
		fromObject(graph)
	if Engine.editor_hint:
		update()
		font = Label.new().get_font("")
	#fromDict({surfaces = [], edges = []})
	
	platStar = preload("PlatStar.gdns").new()


func _process(delta):
	if Engine.editor_hint:
		if queueRedraw:
			update()
			queueRedraw = false

#func _enter_tree():
#	if Engine.editor_hint:
#		fromDict({
#			"surfaces" : [
#				{"ind" : 1, "start" : Vector2(3,4), "end" : Vector2(100,100)},
#				{"ind" : 2, "start" : Vector2(520,4), "end" : Vector2(100,100)},
#				{"ind" : 3, "start" : Vector2(71,-400), "end" : Vector2(371,-400)}
#
#			],
#			"edges" : [
#				[{"ind": 1, "from" : 1, "to" : 3, "exit" : 0, "entrance" : 0, "travType" : JUMP},
#				{"ind": 2, "from" : 1, "to" : 2, "exit" : 0.7, "entrance" : 0.5, "travType" : WALK}]
#			]
#		})

func graphData():
	if (graph == null) or not (graph.is_class("PlatGraph")):
		return {"surfaces": [], "edges": []}
	var surfaces = []
	var edges = edgesFlattened()
	#don't include null surfaces
	for n in graph.surfaces:
		if n != null:
			surfaces.append(n)
#	#collapse all edges for the the editor
#	for earray in graph.edges:
#		edges.append_array(earray)
	return {
		"surfaces" : surfaces,
		"edges" : edges
		}

func getNode(ind):
	return graph.getNode(ind)
func getEdge(ind, from):
	return graph.getEdge(ind, from)

#flatten the 2d array of graph edges, and get rid of nulls
func edgesFlattened():
	var edges = []
	for earray in graph.edges:
		for e in earray:
			if e != null:
				edges.append(e)
	return edges


#this is probably the stupidest way of doin this
static func edgeEntrance(edgeDict, surfaces):
	var surf = surfaces[edgeDict.to]
	return lerp(surf.start, surf.end, edgeDict.entrance)
static func edgeExit(edgeDict, surfaces):
	var surf = surfaces[edgeDict.from]
	return lerp(surf.start, surf.end, edgeDict.exit)


func addNode(ind, start, end):
#	var alreadyExists = ((len(graph.surfaces) > ind)
#			and (graph.surfaces[ind] != null))
	graph.addNode(ind, start, end)
#	if not alreadyExists:
#		nodeHandles.append_array([
#				{ inds = [ind], props = ["start"], pos = start},
#				{ inds = [ind], props = ["end"], pos = end}
#		])
#	queueRedraw = true
	graph.emit_changed()
func newNode(start, end):
	addNode(graph.getAvailableNode(), start, end)

func connectNodes(ind:int, from:int, to:int, exit:float, entrance:float, type: int):
#	var alreadyExists = ((len(graph.edges[from]) > ind)
#			and (graph.edges[from][ind] != null))
	graph.connectNodes(ind, from, to, exit, entrance, type)
	queueRedraw = true
	graph.emit_changed()
#api for adding via the editor
func newEdge(from:int, to:int, exit:Vector2,
			 entrance:Vector2, type:int):
	var fromD = graph.getNode(from)
	var toD = graph.getNode(to)
	connectNodes(
		graph.getAvailableEdge(from),
		from,
		to,
		invVector2Lerp(fromD.start, fromD.end, exit),
		invVector2Lerp(toD.start, toD.end, entrance),
		type
	)

func removeNode(ind):
	graph.removeNode(ind)
	graph.emit_changed()
func removeEdge(ind, from):
	graph.removeEdge(ind, from)
	graph.emit_changed()
	

func getNodeHandles():
	var nodeHandles = []
	for s in graph.surfaces:
		if s is Dictionary:
			nodeHandles.append_array([
				{ inds = [s.ind], props = ["start"], pos = s["start"]},
				{ inds = [s.ind], props = ["end"], pos = s["end"]}
			])
	return nodeHandles
func getEdgeHandles():
	#no real need to store edge handles beforehand
	var handles = []
	var edges = graph.edges
	for from in range(len(graph.edges)):
		if not edges[from] is Array:
			continue
		for ind in range(len(edges[from])):
			var edge = edges[from][ind]
			if edge == null: continue
			handles.append_array([{
				"from" : from, "ind" : ind, "prop" : "exit",
				"pos" : edgeExit(edge, graph.surfaces)},
				{
				"from" : from, "ind" : ind, "prop" : "entrance",
				"pos" : edgeEntrance(edge, graph.surfaces)
				}
			])
	return handles

#inverse of the lerp but for vectors,
static func invVector2Lerp(from:Vector2, to:Vector2, at:Vector2) -> float:
	#'at' may not be exaclty concurrent with to and from
	#we approx to x val, which should be fine as long as it is approx concurrent
	#also clamp it between 0 and 1
	if is_equal_approx(from.x, to.x):
		if is_equal_approx(from.y, to.y):
			return 0.0
		return clamp(inverse_lerp(from.y, to.y, at.y),0 ,1 )
	return clamp(inverse_lerp(from.x, to.x, at.x), 0,1)

#closest point to a straight line
static func closestOnLine(lStart: Vector2, lEnd : Vector2, pos : Vector2):
	var minx = min(lStart.x, lEnd.x)
	var maxx = max(lStart.x, lEnd.x)
	var miny = min(lStart.y, lEnd.y)
	var maxy = max(lStart.y, lEnd.y)
	#for out of bounds
	if pos.x < minx:
		return lStart if lStart.x == minx else lEnd
	if pos.x > maxx:
		return lStart if lStart.x == maxx else lEnd
	if pos.y < miny:
		return lStart if lStart.y == minx else lEnd
	if pos.y < maxy:
		return lStart if lStart.y == maxy else lEnd
	#by intersection
	var m = (lEnd.y - lStart.y) / (lEnd.x - lStart.x)
	#nah screwit
#just use a naive-er xposition based closest point on line
static func closestOnLineByx(lStart: Vector2, lEnd : Vector2, pos : Vector2):
	#vertical or near-vertical line	
	if abs(lEnd.x - lStart.x) < 4:
		var miny = min(lStart.y, lEnd.y)
		var maxy = max(lStart.y, lEnd.y)
		return Vector2((lEnd.x + lStart.x) / 2, clamp(pos.x, miny, maxy))
	
	var m = (lEnd.y - lStart.y) / (lEnd.x - lStart.x)
	#more vertical than horisontal line
	if abs(m) > 1:
		var miny = min(lStart.y, lEnd.y)
		var maxy = max(lStart.y, lEnd.y)
		return Vector2((lEnd.x + lStart.x) / 2, clamp(pos.y, miny, maxy))
	
	var minx = min(lStart.x, lEnd.x)
	var maxx = max(lStart.x, lEnd.x)
	pos.x = clamp(pos.x, minx, maxx)
	pos.y = lStart.y + m*(pos.x - lStart.x)
	return pos
#returns index of closest surface to mous
func closestSurface(pos: Vector2):
	if (graph.surfaces == null):
		return null
	var out = null
	var dist = INF
	var surfaces = graph.surfaces
	var node
	for i in range(len(surfaces)):
		node = surfaces[i]
		if node == null: continue
		var newPoint = closestOnSurface(node, pos)
		var newDist = (newPoint - pos).length()
		if newDist < dist:
			dist = newDist
			out = i
	return out

func closestOnSurface(surf, pos: Vector2):
	if surf is int:
		surf = graph.getNode(surf)
	return closestOnLineByx(
		surf.start, surf.end, pos
	)

#returns dictionary of closest edge to a position of mouse
func closestEdge(pos: Vector2):
	if len(graph.edges) == 0:
		return null
	var out = null
	var dist = INF
	var edges = graph.edges
	var edge
	for f in range(len(edges)):
		for i in range(len(edges[f])):
			edge = edges[f][i]
			if edge == null: continue
			var newPoint = closestOnEdge(edge, pos)
			var newDist = (newPoint - pos).length()
			if newDist < dist:
				dist = newDist
				out = [i, f]
	return out
#returns point on edge (editor) closest to mouse position
func closestOnEdge(edge, pos: Vector2):
	if edge is Array:
		edge = getEdge(edge[0], edge[1])
	return closestOnLineByx(
		edgeExit(edge, graph.surfaces),
		edgeEntrance(edge, graph.surfaces),
		pos
	)



func setHandle(handle : Dictionary, pos : Vector2):
	#is a node handle
	if "inds" in handle:
		var  s = graph.surfaces
		for i in range(len(handle.inds)):
			if handle.props[i] == "start":
				addNode(handle.inds[i], pos, s[handle.inds[i]].end)
			else:
				addNode(handle.inds[i], s[handle.inds[i]].start, pos)
		handle.pos = pos
	elif "from" in handle:
		var e = graph.edges[handle.from][handle.ind]
		var surf
		if handle.prop == "exit": surf = graph.surfaces[e.from]
		else: surf = graph.surfaces[e.to]
		e[handle.prop] = invVector2Lerp(surf.start, surf.end, pos)
		connectNodes(handle.ind, e.from, e.to, e.exit, e.entrance, e.travType)
		handle.pos = pos

func drawLinePointed(start, end, col, w = LINEWIDTH):
	draw_line(start, end, col, w)
	var reversed :Vector2 = ARROWSIZE*(start-end).normalized()
	draw_line(end, end + reversed.rotated(PI/8), col, w)
	draw_line(end, end + reversed.rotated(-PI/8), col, w)
	
func lableLine(start, end, text):
	var pos = (start + end) / 2 + (end-start).rotated(PI/2).normalized() * 10
	draw_string(font, pos, text)
	
func _draw():
	if graph != null and Engine.editor_hint:
		var data = graphData()
		for node in data.surfaces:
			draw_line(node.start, node.end, NODECOL, LINEWIDTH)
			lableLine(node.start, node.end, str(node.ind))
		for edge in data.edges:
			var start = edgeExit(edge, graph.surfaces)
			var end = edgeEntrance(edge, graph.surfaces)
			drawLinePointed(start, end, EDGECOL, LINEWIDTH)
			lableLine(start, end, str(edge.from) + " " + str(edge.to) + " : " 
					+ TypeString[edge.travType])
func free():
	if graph: graph.free()
	.free()
func _onGraphChange():
	queueRedraw = true

#saving, manipluating (handle graphical, textfield direct) and search
func fromDict(dict : Dictionary):
	graph = PlatGraph.new()
	graph.surfaces = dict["surfaces"]
	graph.edges = dict["edges"]
	
	graph.connect("changed", self, "_onGraphChange")
#dististinct from graphData as it keeps nulls and doesn't flattenEdges
func toDict() -> Dictionary:
	if graph == null:
		return {}
	return {
		"surfaces" : graph.surfaces,
		"edges" : graph.edges
	}
func fromObject(obj : Object):
	graph = PlatGraph.new()
	graph.surfaces = obj["surfaces"]
	graph.edges = obj["edges"]
	
	graph.connect("changed", self, "_onGraphChange")
#Godot JSONS store vectors as a string, so we have to extract that when loading
static func poolStringToVector(strings):
	var v
	match len(strings):
		2:
			v = Vector2()
		3:
			v = Vector3()
		_:
			return null
	for i in range(len(strings)):
		if strings[i].is_valid_float():
			v[i] = float(strings[i])
		else:
			return null
	return v
static func extractVectors(thingo):
	match typeof(thingo):
		TYPE_ARRAY:
			var out = []
			for t in thingo:
				out.append(extractVectors(t))
			return out
		TYPE_DICTIONARY:
			var out = {}
			for k in thingo.keys():
				out[k] = extractVectors(thingo[k])
			return out
		TYPE_STRING:
			#could secretly be a vector
			if thingo[0] == "(" and thingo[-1] == ")":
				var v = poolStringToVector(
					thingo.substr(1,len(thingo)-2).split(", ")
				)
				if v is Vector2 or v is Vector3:
					return v
	return thingo
	
#	print(graph.edges)
func loadGraph(path: String):
	#graph is a reference, so we don't bother freeing it
	match path.get_extension():
		"json":
			var file = File.new()
			file.open(path, File.READ)
			var dict = parse_json(file.get_as_text())
			dict = extractVectors(dict)
			file.close()
			fromDict(dict)
			
		"tres":
#			#load it as a Resource and then cast it into a PlatGraph
			var data = load(path)
			fromObject(data)
		_:
			print("file type not recognized")
			return
	graph.emit_changed()
	
func saveGraph(path: String):
	match path.get_extension():
		"json":
			var file = File.new()
			file.open(path, File.WRITE)
			var raw = JSON.print(toDict(), "\t")
			file.store_string(raw)
		"tres":
			ResourceSaver.save(path, graph)
		_:
			print("file type not recognized")
#fix adding edges and inspector, deleting stuff

func query(from:Vector2, to: Vector2, jumpHeight = DEFJUMPHEIGHT):
	return platStar.query(graph, from, to, jumpHeight)
