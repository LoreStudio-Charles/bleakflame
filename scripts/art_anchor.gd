class_name ArtAnchor
## WHERE A PIECE OF GROUND ART MEETS THE GROUND — the one measurement.
##
## A 3/4 top-down sprite is anchored by its BASE: the widest opaque row in its lower half,
## whose left/right ends are the outer corners of the thing's footprint. Everything that
## has to agree about where a prop "stands" reads it from here:
##   · the town, placing the sprite, its projected shadow, and its collider;
##   · tools/make_collider_scenes.gd, laying out the hand-authoring scene.
##
## WHY IT IS SHARED (bug, 2026-07-25): the collider authoring tool had its OWN copy of this
## algorithm, and the two drifted — different search start (0.4 vs 0.5 of height), alpha
## threshold (0.3 vs 0.35), tie-breaking (lowest vs highest row of equal width) and an
## off-by-one on `y`. A polygon authored against one anchor and placed against the other
## sits visibly offset. There must be exactly ONE base row for a given image, so this is it.

## Alpha above which a pixel counts as part of the art.
const OPAQUE := 0.3
## Only the lower part of a sprite can be its base — the top is height, not footprint.
const LOWER := 0.4


## {y, left, right, center} in SOURCE PIXELS, or an all-zero row for a blank image.
## `y` is the base line; `center` is the anchor's x. Ties in width keep the LOWEST row,
## because that is the part actually touching the ground.
static func base_row(img: Image) -> Dictionary:
	var best_w := -1
	var best_y := img.get_height() - 1
	var best_l := 0
	var best_r := img.get_width() - 1
	for y in range(int(img.get_height() * LOWER), img.get_height()):
		var minx := -1
		var maxx := -1
		for x in img.get_width():
			if img.get_pixel(x, y).a > OPAQUE:
				if minx < 0:
					minx = x
				maxx = x
		if minx >= 0 and (maxx - minx) >= best_w:   # >= keeps the LOWEST of tied-width rows
			best_w = maxx - minx
			best_y = y
			best_l = minx
			best_r = maxx
	return {"y": best_y, "left": best_l, "right": best_r, "center": (best_l + best_r) * 0.5}


## The Sprite2D `offset` that puts a base-anchored sprite's base at the node origin — so
## the node's position IS where the thing stands. Both the game and the authoring tool
## place art with this, which is what keeps a hand-drawn polygon aligned in play.
static func base_offset(br: Dictionary) -> Vector2:
	return Vector2(-float(br.center), -float(br.y))
