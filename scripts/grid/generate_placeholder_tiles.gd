@tool
extends EditorScript
## One-off: generates a 48x16 placeholder tileset (floor, wall, deploy marker).
## Run it from the Script editor with File > Run (Ctrl+Shift+X). Safe to delete afterwards.

const PATH := "res://art/placeholder_tiles.png"
const SIZE := 16


func _run() -> void:
	var img := Image.create_empty(SIZE * 3, SIZE, false, Image.FORMAT_RGBA8)

	_tile(img, 0, Color("3a3f5c"), Color("2f3350"))                 # 0: floor
	_tile(img, 1, Color("8a8f9e"), Color("5c6070"))                 # 1: wall
	_tile(img, 2, Color(0.3, 0.6, 1.0, 0.55), Color(0.3, 0.6, 1.0)) # 2: deploy marker

	img.save_png(PATH)
	EditorInterface.get_resource_filesystem().scan()
	print("Saved ", PATH)


## Fills one 16x16 slot with a color and a 1px border, so grid lines stay visible.
func _tile(img: Image, index: int, fill: Color, border: Color) -> void:
	var origin := Vector2i(index * SIZE, 0)
	img.fill_rect(Rect2i(origin, Vector2i(SIZE, SIZE)), border)
	img.fill_rect(Rect2i(origin + Vector2i.ONE, Vector2i(SIZE - 2, SIZE - 2)), fill)
