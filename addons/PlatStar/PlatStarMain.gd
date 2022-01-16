tool
extends EditorPlugin

const EditToolBut = preload("LineEditor.gd")

enum {NONE, NODE, ERASENODE, EDGE, ERAGEEDGE}
var selectedTool = NONE
var lineActive = false
var lineTools = []; 
var activeNav = null

var cursorPos := Vector2()
var lineStart := Vector2()
var lineEnd := Vector2()

var hoveredLine = null
var from = null
var to = null
var edgeType = 0

var heldHandle
var held := false
const HOLDRADIUS = 30
const ERASERCOL = Color(1,0.2,0.1,0.4)

const NODECOLLIGHT = Color.aqua
const EDGECOLLIGHT = Color.bisque
const LINEWIDTH = 2.0
const ARROWHEADLEN = 10.0
const HANDLECOL = Color.azure
const HANDLECOLSEL = Color.aquamarine
const HANDLESIZE = 5


var inspector

var graphLoader
var graphSaver

func _enter_tree():
	var gui = get_editor_interface().get_base_control()
	var navPol = gui.get_icon("NavigationPolygon", "EditorIcons")
	var navObs = gui.get_icon("NavigationObstacle2D", "EditorIcons")
	add_custom_type("PlatGraph", "Resource", preload("PlatGraph.gdns"), navObs)
	add_custom_type("PlatStarNav", "Node2D", preload("PlatStarNav.gd"), navPol)
	
	
	#setting up the tools
	var nodeTool = EditToolBut.new(NODE)
	lineTools.append(nodeTool)
	nodeTool.connect("toggled", self, "_toolSelected", [nodeTool,NODE])
	var eNodeTool = EditToolBut.new(ERASENODE)
	lineTools.append(eNodeTool)
	eNodeTool.connect("toggled", self, "_toolSelected", [eNodeTool, ERASENODE])
	var edgeTool = EditToolBut.new(EDGE)
	lineTools.append(edgeTool)
	edgeTool.connect("toggled", self, "_toolSelected", [edgeTool, EDGE])
	var eEdgeTool = EditToolBut.new(ERAGEEDGE)
	lineTools.append(eEdgeTool)
	eEdgeTool.connect("toggled", self, "_toolSelected", [eEdgeTool, ERAGEEDGE])
	add_control_to_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, nodeTool)
	add_control_to_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, eNodeTool)
	add_control_to_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, edgeTool)
	add_control_to_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, eEdgeTool)
	
	#optionsbutton for choosing type of edge
	var travSel = preload("Inspector/TravTypeSelector.gd").new()
	travSel.connect("item_selected", self, "_travTypeSelected")
	add_control_to_container(CONTAINER_CANVAS_EDITOR_MENU, travSel)
	lineTools.append(travSel)
	#also need tools for deleting surfaces and edges
	
	enableTools(false)
	
	#add the platGraph file dialog to the editor
	graphLoader = preload("OS/GraphOpener.tscn").instance()
	graphSaver = preload("OS/GraphSaver.tscn").instance()
	var baseControl = get_editor_interface().get_base_control()
	baseControl.add_child(graphLoader)
	baseControl.add_child(graphSaver)
	
	#the inspectorr 
	inspector = preload("Inspector/Inspector.gd").new(graphLoader, graphSaver)
	add_inspector_plugin(inspector)
	
	#constants
	add_autoload_singleton("PlatConst", "res://addons/PlatStar/Constants.gd")
	
	
func _exit_tree():
	remove_custom_type("PlatGraph")
	remove_custom_type("PlatStarNav")
	#delete the tools
	
	for t in lineTools:
		t.queue_free()
	
	remove_inspector_plugin(inspector)
	
	remove_autoload_singleton("PlatConst")
	
	graphLoader.queue_free()
	graphSaver.queue_free()
	
func _process(delta):
	if not Engine.editor_hint:
		return
	update_overlays()
	
func handles(object):
	if (object.has_method("get_class")):
		if (not object is Script #get rid of that annoying error
				and object.get_class() == "PlatStarNav"):
			connectNav(object)
			return true
	if activeNav != null:
		disconnectNav(activeNav)
	return false
	
func enableTools(enable = true):
	for t in lineTools:
		t.set_visible(enable)
	if enable == false:
		for t in lineTools:
			t.set_pressed_no_signal(false)
		selectedTool == NONE

func _toolSelected(pressed, but, type, remove = false):
	if pressed:
		unpressTools()
		but.set_pressed_no_signal(true)
		selectedTool = type
	else:
		selectedTool = NONE

#when a travel type is selected on the toolbar
func _travTypeSelected(i):
	edgeType = i
#deselct all the tools
func unpressTools():
	for t in lineTools:
		if t is BaseButton:
			t.set_pressed_no_signal(false)
	selectedTool = NONE

func connectNav(theNav):
	activeNav = theNav
	enableTools(true)
	theNav.connect("tree_exited", self, "disconnectNav", [theNav])

func disconnectNav(theNav):
	if theNav.is_connected("tree_exited", self, "disconnectNav"):
		theNav.disconnect("tree_exited", self, "disconnectNav")
	activeNav = null
	enableTools(false)

func generateThing(pos):
	lineStart = pos
	lineEnd = pos
	lineActive = true
	match selectedTool:
		NODE:
			lineStart = pos
			lineActive = true
		EDGE:
			if hoveredLine != null:
				from = hoveredLine
				lineStart = pos
				lineActive = true
			

func tryAddThing():
	# first check that we can add something
	if (activeNav == null) or (selectedTool == NONE):
		return
	var trans : Transform2D = getCanv().affine_inverse()
	match selectedTool:
		NODE:
			activeNav.newNode(trans.xform(lineStart),
							  trans.xform(lineEnd))
		EDGE:
			#make sure line connects an appropriate surface
			if hoveredLine != null and from != null and from != hoveredLine:
				activeNav.newEdge(from, 
								hoveredLine, 
								trans.xform(lineStart),
								trans.xform(lineEnd),
								edgeType)
			hoveredLine = null
			from = null

#handle mouse is hovering over
func getHeldHandle(pos, type = NONE):
	if activeNav == null: return null
	#var trans = getCanv().affine_inverse()
	match type:
		NODE:	
			return closestHandle(activeNav, NODE, pos, HOLDRADIUS)
		EDGE:
			return closestHandle(activeNav, EDGE, pos, HOLDRADIUS)

func closestHandle(nav, type :int, pos : Vector2, radius: float):
	var handles = nav.getNodeHandles() if type == NODE else activeNav.getEdgeHandles()
	if handles == null: return null
	var out = null
	var dist = radius
	var trans = getCanv()
	for h in handles:
		var newPoint = trans.xform(h.pos)
		var newDist = (newPoint - pos).length()
		if newDist < dist:
			dist = newDist
			out = h
	return out

func closestSurface(nav, pos):
	var trans = getCanv()
	var localPos = trans.affine_inverse().xform(pos)
	var surfInd = nav.closestSurface(localPos)
	if surfInd == null: return null
	var theSurf = nav.getNode(surfInd)
	var point = trans.xform(nav.closestOnSurface(theSurf, localPos))
	if (point - pos).length() < HOLDRADIUS:
		cursorPos = point
		return surfInd
	else:
		return null

func closestEdge(nav, pos):
	var trans = getCanv()
	var localPos = trans.affine_inverse().xform(pos)
	var edgeCoord = nav.closestEdge(localPos)
	if edgeCoord == null: return null
	var theEdge = nav.callv("getEdge", edgeCoord)
	var point = trans.xform(nav.closestOnEdge(theEdge, localPos))
	if (point - pos).length() < HOLDRADIUS:
		return edgeCoord
	else:
		return null

func trySetHandle(pos, h):
	if activeNav == null: return null
	var trans = getCanv().affine_inverse()
	activeNav.setHandle(h, trans.xform(pos))
func getCanv():
	return get_editor_interface().get_edited_scene_root().get_parent().get_final_transform()

func drawArrow(overlay, start, end, col, width):
	var reversed = ARROWHEADLEN*(start - end).normalized()
	overlay.draw_line(start, end, col, width)
	overlay.draw_line(end, end+reversed.rotated(PI/8), col, width)
	overlay.draw_line(end, end+reversed.rotated(-PI/8), col, width)

func drawHandles(overlay, handles, trans):
	if handles != null:
		for h in handles:
			overlay.draw_circle(trans.xform(h.pos), HANDLESIZE, HANDLECOL)

func forward_canvas_gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT:
			if event.pressed:
				#choose between manipulating a handle or drawing anew line
				if heldHandle != null:
					held = true
				else:
					generateThing(cursorPos)
			else:
				#could either change thingy of handle and adding new line
				if lineActive:
					lineActive = false
					tryAddThing()
				else:
					held = false
					
	if event is InputEventMouseMotion:
		#logic with the cursor
		match selectedTool:
			NODE:
				cursorPos = event.position
			ERASENODE:
				cursorPos = event.position
				#snap the the edge if it is there
				if activeNav != null and Input.is_mouse_button_pressed(BUTTON_LEFT):
					#will also set cursor pos
					hoveredLine = closestSurface(activeNav, event.position)
					if hoveredLine!= null:
						activeNav.removeNode(hoveredLine)
				else:
					hoveredLine = null
			EDGE:
				#snap the the edge if it is there
				if activeNav != null:
					#will also set cursor pos
					hoveredLine = closestSurface(activeNav, event.position)
					if hoveredLine == null:
						cursorPos = event.position
				else:
					cursorPos = event.position
					hoveredLine = null
			ERAGEEDGE:
				cursorPos = event.position
				#snap the the edge if it is there
				if activeNav != null and Input.is_mouse_button_pressed(BUTTON_LEFT):
					#will also set cursor pos
					hoveredLine = closestEdge(activeNav, event.position)
					if hoveredLine != null:
						activeNav.removeEdge(hoveredLine[0], hoveredLine[1])
				else:
					hoveredLine = null
		if lineActive:
			lineEnd = cursorPos
		else:
			if held:
				trySetHandle(cursorPos, heldHandle)
			else:
				heldHandle = getHeldHandle(cursorPos, selectedTool)
	return lineActive or held


func forward_canvas_draw_over_viewport(overlay):
	var trans : Transform2D = getCanv()
	if lineActive:
		var start = (lineStart)
		var end = (lineEnd)
		match selectedTool:
			NODE:
				overlay.draw_line(start, end, NODECOLLIGHT, LINEWIDTH)
			EDGE:
				drawArrow(overlay, start, end, EDGECOLLIGHT, LINEWIDTH)
	#now draw all the handles
	if activeNav != null:
		match selectedTool:
			NODE:
				drawHandles(overlay, activeNav.getNodeHandles(), trans)
			EDGE:
				drawHandles(overlay, activeNav.getEdgeHandles(), trans)
			ERASENODE, ERAGEEDGE:
				overlay.draw_circle(cursorPos, HOLDRADIUS, ERASERCOL)
			_:
				drawHandles(overlay, activeNav.getNodeHandles(), trans)
				drawHandles(overlay, activeNav.getEdgeHandles(), trans)
	if heldHandle != null:
		overlay.draw_circle(trans.xform(heldHandle.pos), HANDLESIZE, HANDLECOLSEL)
		#print(heldHandle.pos)

