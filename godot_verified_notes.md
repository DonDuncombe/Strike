# Verified Godot 4.7.1 notes for Strike

Project-specific findings confirmed against `godot_4_7_reference.md` and tested in the installed Godot 4.7.1 engine.
Add an entry only after it has been verified; include the date and how it was checked.
`godot_4_7_reference.md` is generated from engine sources ("DO NOT EDIT"), so notes live here instead.

## 2D draw order (verified 2026-09-26)

Source: `godot_4_7_reference.md`, CanvasItem description and `z_index` / `z_as_relative`, and CanvasLayer `layer`.

- Canvas items draw in scene-tree order: later siblings draw on top of earlier ones, and children draw on top of their parent.
- `CanvasItem.z_index` (range -4096 to 4096, default 0) overrides tree order. Items only sort by tree order against items with the same final Z index.
- `z_as_relative` (default true) adds the parent's final Z index, so a child with `z_index = -1` under a parent at 0 ends up at -1.
- `CanvasLayer.layer` separates whole layers. The default 2D world is layer 0; a higher layer always draws above lower layers, whatever the `z_index` of the nodes inside.

Project layering convention. Set the Z index in the reusable scene's root, not per instance, so every instance keeps its layer wherever it is placed in the tree:

| Element | How it is layered |
|---|---|
| Collectibles such as `dash_orb_small.tscn` / `dash_orb_large.tscn` | Root `z_index = -1`, behind actors and terrain |
| Player, level tiles, static bodies | `z_index = 0`, ordered by scene tree (Player currently draws behind the `CollisionGrid` tiles) |
| HUD (`hud.tscn`) | `CanvasLayer` with `layer = 10`, above the whole world |

Verification: a windowed (not headless) run rendered `main.tscn` with the Player overlapping a dash orb and saved the viewport with `root.get_texture().get_image()` after `RenderingServer.frame_post_draw`. With orb `z_index = -1` the Player drew in front; with `z_index = 0` the orb, which comes later in the tree, covered the Player. Headless runs do not render, so draw order needs a windowed capture or a manual check.
