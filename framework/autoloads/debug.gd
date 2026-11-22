extends Node
@export var parent_container:Control
@export var watch_pannel:RichTextLabel
@export var graph_pannel:Control

var _watches:Dictionary = {}
var _graphs:Dictionary = {}
var _graph_widgets: Dictionary = {}
var _graph_max_sample:int = 80
var _is_debug:bool = OS.is_debug_build()
var _visible:bool = false

func _ready() -> void:
	parent_container.visible = _visible
	if watch_pannel:
		watch_pannel.fit_content = true
		watch_pannel.scroll_active = false

func watch(key:String,value:Variant,color:Color = Color.WHITE) -> void:
	if not _is_debug:
		return
	_watches[key] = {"value":value,"color":color}

func graph(key:String,value:Variant) -> void:
	if not _is_debug:
		return
	if key not in _graphs:
		_graphs[key] = []
	var g:Array = _graphs[key]
	g.append(value)
	if g.size() > _graph_max_sample:
		g.pop_front()

func _input(event:InputEvent) -> void:
	if _is_debug and event.is_action_pressed("debug"):
		toggle_visible()
		parent_container.visible = _visible

func log_event(message: String) -> void:
	if not _is_debug: return
	print("[DEBUG %.3f] %s" % [Time.get_ticks_msec() / 1000.0, message])

func toggle_visible():
	_visible = not _visible

func get_watches() -> Dictionary:
	return _watches

func get_graphs() -> Dictionary:
	return _graphs

func refresh_watch_entries():
	var watches_text = ""
	for key in _watches:
		if _watches[key]["value"] is Dictionary:
			for key2 in _watches[key]["value"]:
				var value = _watches[key]["value"][key2]
				var color = _watches[key]["color"]
				watches_text += "[color=%s][b]%s:[/b] %s[/color]\n" % [color.to_html(), key2, str(value)]
		
		elif _watches[key]["value"] is Array:
			for value in _watches[key]["value"]:
				watches_text += "[color=%s] %s[/color]\n" % [_watches[key]["color"].to_html(), str(value)]
			continue
		else:
			var value = _watches[key]["value"]
			var color = _watches[key]["color"]
			watches_text += "[color=%s][b]%s:[/b] %s[/color]\n" % [color.to_html(), key, str(value)]
		watch_pannel.text = watches_text
	

func construct_graph_entry(key:String,samples:Array):
	var v_box = VBoxContainer.new()
	var label = Label.new()
	label.text = key + ":"
	v_box.add_child(label)
	var graph = GraphEdit.new()
	graph.draw.connect(_on_graph_draw.bind(graph, samples))
	v_box.add_child(graph)
	return v_box

func _on_graph_draw(canvas: Control, samples: Array) -> void:
	if samples.is_empty():
		return
	# Draw a subtle background box
	canvas.draw_rect(Rect2(Vector2.ZERO, canvas.size), Color(0.1, 0.1, 0.1, 0.6))
	# Find min/max to auto-scale the graph vertically
	var max_val: float = -INF
	var min_val: float = INF
	for val in samples:
		max_val = max(max_val, float(val))
		min_val = min(min_val, float(val))
	var val_range: float = max(max_val - min_val, 0.001)
	var points: PackedVector2Array = []
	for i in range(samples.size()):
		var x: float = (float(i) / max(1, samples.size() - 1)) * canvas.size.x
		# Invert Y so higher values appear at the top
		var normalized_y: float = (float(samples[i]) - min_val) / val_range
		var y: float = canvas.size.y - (normalized_y * canvas.size.y)
		points.append(Vector2(x, y))
	if points.size() > 1:
		canvas.draw_polyline(points, Color.GREEN, 1.5)


func populate_graph_pannel() -> void:
	if not graph_pannel:
		return
	for key in _graphs:
		var samples: Array = _graphs[key]
		if key not in _graph_widgets:
			# 1. Create entry ONCE
			var v_box := VBoxContainer.new()
			var label := Label.new()
			label.text = key + ":"
			v_box.add_child(label)
			# Use a lightweight Control instead of a heavy GraphEdit
			var canvas := Control.new()
			canvas.custom_minimum_size = Vector2(200, 60)
			canvas.draw.connect(_on_graph_draw.bind(canvas, samples))
			v_box.add_child(canvas)
			graph_pannel.add_child(v_box)
			_graph_widgets[key] = canvas
		else:
			# 2. Update EXISTING graph by requesting a redraw
			_graph_widgets[key].queue_redraw()

func _process(delta:float):
	if not _is_debug:
		return
	if _visible:
		refresh_watch_entries()
		populate_graph_pannel()
