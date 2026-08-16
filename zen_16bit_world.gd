extends Node2D

const SECTION_SIZE := Vector2(720.0, 1280.0)
const SECTION_STEP_Y := 1152.0
const START_CENTER_Y := 572.0
const CHAPTERS := [
	preload("res://assets/skins/zen/v2/chapter_0.png"),
	preload("res://assets/skins/zen/v2/chapter_1.png"),
	preload("res://assets/skins/zen/v2/chapter_2.png"),
	preload("res://assets/skins/zen/v2/chapter_3.png"),
	preload("res://assets/skins/zen/v2/chapter_4.png"),
]


func _ready() -> void:
	z_index = -100
	for index in range(CHAPTERS.size()):
		var chapter := Sprite2D.new()
		chapter.name = "ZenChapter%d" % index
		chapter.texture = CHAPTERS[index]
		chapter.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		chapter.position = Vector2(360.0, START_CENTER_Y - SECTION_STEP_Y * index)
		add_child(chapter)
	RenderingServer.set_default_clear_color(Color("101B3A"))
