extends EditorInspectorPlugin
tool# just make everything a tool idk

var Prop = preload("res://addons/PlatStar/Inspector/GraphEditorProp.gd")
var Filer = preload("res://addons/PlatStar/OS/GraphFileProp.gd")
var graphLoader
var graphSaver


func _init(loader, saver):
	graphLoader = loader
	graphSaver = saver
#only edit plat graphs and plat navs for now
func can_handle(object):
	return ["PlatStarNav"].has(object.get_class()) or object.is_class("PlatGraph")
	
func parse_property(object, type, path, hint, hintText, usage):
	if object.is_class("PlatGraph"):
		if type == TYPE_ARRAY:
			var newProp
			if path == "surfaces":
				newProp = Prop.new("Nodes")
	#			add_property_editor(path, newProp)
	#			object.connect("changed", newProp, "update_property")
			elif path == "edges":
				newProp = Prop.new("Edges")
			add_property_editor(path, newProp)
			object.connect("changed", newProp, "update_property")
			
	#		elif path == "edges":
	#			add_property_editor(path, Prop.new("Edges"))
			return true
	if object.get_class() == ("PlatStarNav"):
		if path == "graph":
			#force the inspector to parse the graph first, then add the
			#load/save thing in
#				parse_property(object.graph, TYPE_ARRAY ,"graph/surfaces", PROPERTY_HINT_NONE, "nodes aka surfs", PROPERTY_USAGE_DEFAULT)
#				parse_property(object.graph, TYPE_ARRAY ,"graph/edges", PROPERTY_HINT_NONE, "between surfs", PROPERTY_USAGE_DEFAULT)
			add_property_editor("", Filer.new(object, graphLoader, graphSaver))
			return false
	return false
