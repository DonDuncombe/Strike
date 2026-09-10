@tool
extends EditorScript

func _run():
	# Step 1: Create a 64x64 image in RGBA8 format
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color.BLACK)

	# Step 2: Use the static constructor to create a texture from the image
	var tex := ImageTexture.create_from_image(img)

	# Step 3: Print dimensions to confirm
	print("Texture size before save: %d x %d" % [tex.get_width(), tex.get_height()])

	# Step 4: Save the texture as a .tres resource
	var error := ResourceSaver.save(tex, "res://collision_tile.tres")
	if error != OK:
		push_error("Failed to save texture: %s" % error)
	else:
		print("Saved collision_tile.tres successfully")
