extends TileMapLayer

@export var width := 40
@export var height := 30
@export var noise_seed := 0            # 0 = new random seed each run
@export var noise_frequency := 0.08    # lower = bigger blobs
@export var dirt_threshold := 0.1      # higher = less dirt
@export var atlas_source_id := 0       # your atlas source in the TileSet

@export_group("Flowers")
@export var flower_chance := 0.08      # chance per eligible grass cell
@export var flower_patch_frequency := 0.15  # lower = bigger flower patches
@export var flower_patch_threshold := -0.2  # higher = fewer patches
@export var flower_jitter := 0.35      # random offset inside the cell (0 = centered)

const GRASS := 0
const DIRT := 1

const FLOWER_SCENES: Array[PackedScene] = [
	preload("res://World/Flowers/Scenes/chamomile.tscn"),
	preload("res://World/Flowers/Scenes/dandelion.tscn"),
	preload("res://World/Flowers/Scenes/fox_gloves.tscn"),
]

var world := {}                        # Vector2i -> GRASS or DIRT
var atlas_lookup := {}                 # key -> atlas coords, built automatically
var fallback := Vector2i.ZERO
var flower_container: Node2D

# Key = (top_left << 3) | (top_right << 2) | (bottom_left << 1) | bottom_right
# Grass = 0, Dirt = 1

func _ready() -> void:
	# Shift the display layer by half a tile (dual-grid trick)
	position = -Vector2(tile_set.tile_size) / 2.0

	# Container that cancels the half-tile shift, so flowers use normal world coordinates
	flower_container = Node2D.new()
	flower_container.name = "Flowers"
	flower_container.position = Vector2(tile_set.tile_size) / 2.0
	flower_container.y_sort_enabled = true
	add_child(flower_container)

	build_lookup()
	generate()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):  # Enter / Space = regenerate
		generate()

# Looks at the 4 quadrants of every tile in the atlas and decides grass or dirt
func build_lookup() -> void:
	atlas_lookup.clear()

	var source := tile_set.get_source(atlas_source_id) as TileSetAtlasSource
	var img := source.texture.get_image()
	if img.is_compressed():
		img.decompress()

	# sample points inside each quadrant: TL, TR, BL, BR
	var samples: Array[Vector2] = [
		Vector2(0.25, 0.25), Vector2(0.75, 0.25),
		Vector2(0.25, 0.75), Vector2(0.75, 0.75),
	]

	for i in source.get_tiles_count():
		var coords := source.get_tile_id(i)
		var rect := source.get_tile_texture_region(coords)

		var key := 0
		for s in samples:
			var px := rect.position + Vector2i(Vector2(rect.size) * s)
			var c := img.get_pixelv(px)
			var is_dirt := c.r > c.g          # brown has more red, grass has more green
			key = (key << 1) | (DIRT if is_dirt else GRASS)

		if not atlas_lookup.has(key):
			atlas_lookup[key] = coords

	fallback = atlas_lookup.get(0b0000, Vector2i.ZERO)

	for key in 16:
		if not atlas_lookup.has(key):
			push_warning("Atlas has no tile for corners " + String.num_int64(key, 2).pad_zeros(4))

func generate() -> void:
	clear()
	world.clear()
	clear_flowers()

	var used_seed := noise_seed if noise_seed != 0 else randi()

	var noise := FastNoiseLite.new()
	noise.seed = used_seed
	noise.frequency = noise_frequency

	# 1. Fill the logical grid
	for x in width:
		for y in height:
			world[Vector2i(x, y)] = DIRT if noise.get_noise_2d(x, y) > dirt_threshold else GRASS

	# 2. Draw the display tiles (one extra row/column for the border)
	for x in width + 1:
		for y in height + 1:
			update_display_cell(Vector2i(x, y))

	# 3. Scatter flowers
	spawn_flowers(used_seed)

func clear_flowers() -> void:
	for f in flower_container.get_children():
		f.queue_free()

func spawn_flowers(used_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = used_seed

	var patch_noise := FastNoiseLite.new()
	patch_noise.seed = used_seed + 1
	patch_noise.frequency = flower_patch_frequency

	var tile_size := Vector2(tile_set.tile_size)

	for x in width:
		for y in height:
			var cell := Vector2i(x, y)

			# only in flower patches, only by chance
			if patch_noise.get_noise_2d(x, y) < flower_patch_threshold:
				continue
			if rng.randf() > flower_chance:
				continue
			if not is_safe_grass(cell):
				continue

			var flower := FLOWER_SCENES[rng.randi() % FLOWER_SCENES.size()].instantiate() as Node2D
			var jitter := Vector2(
				rng.randf_range(-1.0, 1.0),
				rng.randf_range(-1.0, 1.0)
			) * tile_size * flower_jitter * 0.5
			flower.position = Vector2(cell) * tile_size + tile_size / 2.0 + jitter
			flower_container.add_child(flower)

# A cell is safe for flowers if it and all 8 neighbors are grass
func is_safe_grass(cell: Vector2i) -> bool:
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var p := cell + Vector2i(dx, dy)
			# outside the map counts as grass, but skip the map border for a cleaner edge
			if not world.has(p) and (dx != 0 or dy != 0):
				continue
			if get_world_tile(p) != GRASS:
				return false
	return true

func get_world_tile(p: Vector2i) -> int:
	return world.get(p, GRASS)  # outside the map = grass

func update_display_cell(p: Vector2i) -> void:
	var tl := get_world_tile(p + Vector2i(-1, -1))
	var tr := get_world_tile(p + Vector2i(0, -1))
	var bl := get_world_tile(p + Vector2i(-1, 0))
	var br := get_world_tile(p)

	var key := (tl << 3) | (tr << 2) | (bl << 1) | br
	var atlas: Vector2i = atlas_lookup.get(key, fallback)

	set_cell(p, atlas_source_id, atlas)
