class_name Spectators extends Node3D

# Genera spettatori billboard 2D stile retro ai lati della partenza.
# Ogni spettatore è un Sprite3D con billboard_mode che mostra un "omino" pixel-art
# generato proceduralmente, con variazioni di colori e altezza.
# L'animazione alterna tra due frame (mani giù / mani su) a velocità casuali.

## Numero di spettatori da generare.
@export var count: int = 10
## Raggio entro il quale gli spettatori vengono piazzati dalla posizione di spawn.
@export var spread_radius: float = 14.0
## Distanza minima dal centro strada.
@export var min_road_distance: float = 4.0
## Altezza degli sprite nel mondo (metri).
@export var sprite_height: float = 1.6
## Seed per la generazione casuale.
@export var rng_seed: int = 42

# Dimensioni del pixel art (larghezza x altezza in pixel).
const PIX_W := 16
const PIX_H := 24

# Paletta colori pelle
const SKIN_COLORS: Array[Color] = [
	Color(0.96, 0.80, 0.65),  # chiara
	Color(0.87, 0.72, 0.53),  # media
	Color(0.76, 0.60, 0.42),  # olivastra
	Color(0.55, 0.38, 0.26),  # scura
	Color(0.40, 0.26, 0.18),  # molto scura
]

# Paletta colori magliette
const SHIRT_COLORS: Array[Color] = [
	Color(0.85, 0.15, 0.15),  # rosso
	Color(0.15, 0.50, 0.85),  # blu
	Color(0.20, 0.70, 0.20),  # verde
	Color(0.90, 0.85, 0.10),  # giallo
	Color(0.90, 0.45, 0.10),  # arancione
	Color(0.60, 0.20, 0.70),  # viola
	Color(0.95, 0.95, 0.95),  # bianco
	Color(0.15, 0.15, 0.15),  # nero
	Color(0.85, 0.40, 0.60),  # rosa
	Color(0.10, 0.75, 0.75),  # ciano
]

# Paletta colori pantaloni
const PANTS_COLORS: Array[Color] = [
	Color(0.18, 0.22, 0.55),  # jeans
	Color(0.12, 0.12, 0.12),  # nero
	Color(0.35, 0.25, 0.18),  # marrone
	Color(0.30, 0.32, 0.30),  # grigio scuro
	Color(0.55, 0.45, 0.35),  # khaki
]

# Paletta colori capelli
const HAIR_COLORS: Array[Color] = [
	Color(0.10, 0.08, 0.06),  # nero
	Color(0.35, 0.20, 0.10),  # castano
	Color(0.85, 0.65, 0.25),  # biondo
	Color(0.60, 0.25, 0.10),  # rosso
	Color(0.45, 0.45, 0.45),  # grigio
]

# Stili di capelli: lista di offset pixel [x, y] relativi alla testa.
# 0 = corto, 1 = medio, 2 = lungo, 3 = calvo
const HAIR_STYLES := 4

var _sprites: Array[Sprite3D] = []
var _textures_down: Array[ImageTexture] = []
var _textures_up: Array[ImageTexture] = []
var _anim_timers: PackedFloat32Array = PackedFloat32Array()
var _anim_speeds: PackedFloat32Array = PackedFloat32Array()
var _anim_offsets: PackedFloat32Array = PackedFloat32Array()

## Va chiamato dopo che il road ha fatto build(), passandogli il transform della partenza
## e la direzione della strada, cosi' gli spettatori vengono piazzati ai lati.
func spawn(start_pos: Vector3, road_dir: Vector3, road_side: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	for i in count:
		var skin_col := SKIN_COLORS[rng.randi_range(0, SKIN_COLORS.size() - 1)]
		var shirt_col := SHIRT_COLORS[rng.randi_range(0, SHIRT_COLORS.size() - 1)]
		var pants_col := PANTS_COLORS[rng.randi_range(0, PANTS_COLORS.size() - 1)]
		var hair_col := HAIR_COLORS[rng.randi_range(0, HAIR_COLORS.size() - 1)]
		var hair_style := rng.randi_range(0, HAIR_STYLES - 1)
		var height_scale := rng.randf_range(0.85, 1.15)

		var img_down := _draw_person(skin_col, shirt_col, pants_col, hair_col, hair_style, false)
		var img_up := _draw_person(skin_col, shirt_col, pants_col, hair_col, hair_style, true)

		var tex_down := ImageTexture.create_from_image(img_down)
		var tex_up := ImageTexture.create_from_image(img_up)
		_textures_down.append(tex_down)
		_textures_up.append(tex_up)

		var sprite := Sprite3D.new()
		sprite.texture = tex_down
		sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sprite.pixel_size = (sprite_height * height_scale) / float(PIX_H)
		sprite.transparent = true
		sprite.no_depth_test = false
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.shaded = true

		# Posizionamento: laterale rispetto alla strada, con un po' di avanzamento casuale
		var side_sign := -1.0 if (i % 2 == 0) else 1.0
		var lateral := rng.randf_range(min_road_distance, spread_radius) * side_sign
		var forward := rng.randf_range(-4.0, 8.0)
		var pos := start_pos + road_side * lateral + road_dir * forward
		pos.y = start_pos.y  # stessa quota della partenza
		sprite.position = pos
		sprite.position.y += sprite_height * height_scale * 0.5  # piedi a terra

		add_child(sprite)
		_sprites.append(sprite)

		# Timer e velocità diverse per ogni spettatore
		_anim_timers.append(0.0)
		_anim_speeds.append(rng.randf_range(1.5, 4.0))  # cicli al secondo
		_anim_offsets.append(rng.randf_range(0.0, TAU))  # offset fase


func _process(delta: float) -> void:
	for i in _sprites.size():
		_anim_timers[i] += delta
		var phase := sin(_anim_timers[i] * _anim_speeds[i] + _anim_offsets[i])
		if phase > 0.0:
			_sprites[i].texture = _textures_up[i]
		else:
			_sprites[i].texture = _textures_down[i]


# Disegna un omino pixel art su un'immagine PIX_W x PIX_H.
# hands_up: se true, le braccia sono alzate.
func _draw_person(skin: Color, shirt: Color, pants: Color, hair_col: Color,
		hair_style: int, hands_up: bool) -> Image:
	var img := Image.create(PIX_W, PIX_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))  # trasparente

	var cx := PIX_W / 2  # 8

	# --- Capelli (sopra la testa) ---
	match hair_style:
		0:  # corto: riga sopra la testa
			for x in range(cx - 2, cx + 3):
				img.set_pixel(x, 2, hair_col)
			for x in range(cx - 2, cx + 3):
				img.set_pixel(x, 3, hair_col)
		1:  # medio: copre la testa e scende ai lati
			for x in range(cx - 2, cx + 3):
				img.set_pixel(x, 2, hair_col)
			for x in range(cx - 3, cx + 4):
				img.set_pixel(x, 3, hair_col)
			img.set_pixel(cx - 3, 4, hair_col)
			img.set_pixel(cx + 3, 4, hair_col)
			img.set_pixel(cx - 3, 5, hair_col)
			img.set_pixel(cx + 3, 5, hair_col)
		2:  # lungo: scende sotto le orecchie
			for x in range(cx - 2, cx + 3):
				img.set_pixel(x, 2, hair_col)
			for x in range(cx - 3, cx + 4):
				img.set_pixel(x, 3, hair_col)
			img.set_pixel(cx - 3, 4, hair_col)
			img.set_pixel(cx + 3, 4, hair_col)
			img.set_pixel(cx - 3, 5, hair_col)
			img.set_pixel(cx + 3, 5, hair_col)
			img.set_pixel(cx - 3, 6, hair_col)
			img.set_pixel(cx + 3, 6, hair_col)
			img.set_pixel(cx - 3, 7, hair_col)
			img.set_pixel(cx + 3, 7, hair_col)
		3:  # calvo: niente capelli
			pass

	# --- Testa (faccia) ---
	for y in range(3, 7):
		for x in range(cx - 2, cx + 3):
			if img.get_pixel(x, y).a < 0.5:  # non sovrascrivere i capelli
				img.set_pixel(x, y, skin)

	# Occhi
	var eye_color := Color(0.1, 0.1, 0.1)
	img.set_pixel(cx - 1, 4, eye_color)
	img.set_pixel(cx + 1, 4, eye_color)

	# Bocca (sorriso)
	img.set_pixel(cx, 5, Color(0.7, 0.2, 0.2))

	# --- Collo ---
	img.set_pixel(cx, 7, skin)

	# --- Corpo (maglietta) ---
	if hands_up:
		# Busto
		for y in range(8, 14):
			for x in range(cx - 2, cx + 3):
				img.set_pixel(x, y, shirt)
		# Braccia alzate
		for y in range(3, 9):
			img.set_pixel(cx - 3, y, shirt)
			img.set_pixel(cx - 4, y, shirt)
			img.set_pixel(cx + 3, y, shirt)
			img.set_pixel(cx + 4, y, shirt)
		# Mani in alto
		for y in range(2, 4):
			img.set_pixel(cx - 4, y, skin)
			img.set_pixel(cx - 3, y, skin)
			img.set_pixel(cx + 3, y, skin)
			img.set_pixel(cx + 4, y, skin)
	else:
		# Busto
		for y in range(8, 14):
			for x in range(cx - 2, cx + 3):
				img.set_pixel(x, y, shirt)
		# Braccia abbassate
		for y in range(8, 14):
			img.set_pixel(cx - 3, y, shirt)
			img.set_pixel(cx + 3, y, shirt)
		# Mani giù
		for y in range(13, 15):
			img.set_pixel(cx - 3, y, skin)
			img.set_pixel(cx + 3, y, skin)

	# --- Gambe (pantaloni) ---
	for y in range(14, 20):
		img.set_pixel(cx - 2, y, pants)
		img.set_pixel(cx - 1, y, pants)
		img.set_pixel(cx + 1, y, pants)
		img.set_pixel(cx + 2, y, pants)

	# --- Scarpe ---
	var shoe_color := Color(0.15, 0.12, 0.10)
	for y in range(20, 22):
		img.set_pixel(cx - 2, y, shoe_color)
		img.set_pixel(cx - 1, y, shoe_color)
		img.set_pixel(cx + 1, y, shoe_color)
		img.set_pixel(cx + 2, y, shoe_color)

	return img
