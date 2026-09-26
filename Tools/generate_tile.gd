@tool
extends EditorScript

const OUTPUT_PATH: String = "res://assets/images/Tiles/collision_tile.tres"

# Regenerates the solid 64x64 texture used by the CollisionGrid tile set in main.tscn.
func _run() -> void:
	var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color.BLACK)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	var error: Error = ResourceSaver.save(tex, OUTPUT_PATH)
	if error != OK:
		push_error("Failed to save %s: %s" % [OUTPUT_PATH, error_string(error)])
	else:
		print("Saved %s (%d x %d)" % [OUTPUT_PATH, tex.get_width(), tex.get_height()])
