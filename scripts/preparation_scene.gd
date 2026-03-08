extends Node2D

# --- DATI BOTTIGLIE: nome, colore del liquido e sprite ---
const BOTTLES = [
	{ "name": "rosso",     "color": Color(0.8, 0.1, 0.1), "sprite": "res://assets/bottles/bottle_red.png" },
	{ "name": "blu",       "color": Color(0.1, 0.1, 0.9), "sprite": "res://assets/bottles/bottle_blue.png" },
	{ "name": "verde",     "color": Color(0.1, 0.8, 0.1), "sprite": "res://assets/bottles/bottle_green.png" },
	{ "name": "giallo",    "color": Color(0.9, 0.9, 0.1), "sprite": "res://assets/bottles/bottle_yellow.png" },
	{ "name": "viola",     "color": Color(0.6, 0.1, 0.8), "sprite": "res://assets/bottles/bottle_purple.png" },
	{ "name": "arancione", "color": Color(0.9, 0.5, 0.1), "sprite": "res://assets/bottles/bottle_orange.png" },
	{ "name": "celeste",   "color": Color(0.4, 0.8, 1.0), "sprite": "res://assets/bottles/bottle_lightblue.png" },
	{ "name": "rosa",      "color": Color(1.0, 0.4, 0.7), "sprite": "res://assets/bottles/bottle_pink.png" },
]

# --- DATI BICCHIERI: nome, sprite e parametri del liquido visivo ---
const GLASSES = [
	{ "name": "classico",  "sprite": "res://assets/glasses/glass.png",           "liquid_width": 40.0, "liquid_height": 60.0, "liquid_offset_y": -15.0 },
	{ "name": "calice",    "sprite": "res://assets/glasses/glass_calice.png",    "liquid_width": 40.0, "liquid_height": 30.0, "liquid_offset_y": -50.0 },
	{ "name": "triangolo", "sprite": "res://assets/glasses/glass_triangolo.png", "liquid_width": 30.0, "liquid_height": 30.0, "liquid_offset_y": -40.0 },
	{ "name": "shot",      "sprite": "res://assets/glasses/glass_shot.png",      "liquid_width": 31.0, "liquid_height": 40.0, "liquid_offset_y": -25.0 },
]

# --- RIFERIMENTI AI NODI ---
@onready var timer_bar: ProgressBar = $UI/TimerBar                      # barra del tempo rimasto
@onready var order_label: Label = $UI/OrderLabel                        # mostra l'ordine da preparare
@onready var glass_menu: Control = $UI/GlassMenu                        # pannello menu bicchieri
@onready var bottle_menu: Control = $UI/BottleMenu                      # pannello menu bottiglie
@onready var glass_menu_button: Button = $UI/GlassMenuButton            # apre/chiude il menu bicchieri
@onready var bottle_menu_button: Button = $UI/BottleMenuButton          # apre/chiude il menu bottiglie
@onready var confirm_button: TextureButton = $UI/ConfirmButton          # conferma il drink e torna al bancone
@onready var trash_button: TextureButton = $UI/TrashButton              # svuota il bicchiere e ricomincia
@onready var glass_spot: Node2D = $GlassSpot                            # punto centrale dove appare il bicchiere
@onready var particles_container: Node2D = $ParticlesContainer          # contenitore particelle (non usato direttamente, le particelle vanno in glass_spot)
@onready var countdown_timer: Timer = $Timer                            # timer che fa tick ogni 0.1s

# --- VARIABILI DI STATO ---
var selected_glass: Dictionary = {}        # bicchiere attualmente selezionato
var glass_sprite: Sprite2D = null          # sprite del bicchiere attuale
var dragging_bottle: Dictionary = {}       # bottiglia che si sta trascinando
var dragging_sprite: Sprite2D = null       # sprite della bottiglia trascinata
var is_dragging: bool = false              # true se si sta trascinando una bottiglia
var poured_colors: Array = []              # colori versati nel bicchiere
var liquid_level: float = 0.0             # livello attuale del liquido (0-100)
var max_liquid: float = 100.0             # livello massimo raggiungibile
var is_pouring: bool = false              # true durante l'animazione di versamento
var particle_stream: Array = []            # lista delle particelle attive dello stream

# -------------------------------------------------------
func _ready():
	# Nascondi elementi che appaiono solo dopo certe azioni
	confirm_button.visible = false
	trash_button.visible = false
	glass_menu.visible = false
	bottle_menu.visible = false

	# Mostra l'ordine da preparare preso da GameData
	order_label.text = "Ordine: " + ", ".join(GameData.current_order)

	# Inizializza la barra del tempo con il tempo già trascorso (continua dal bancone)
	timer_bar.max_value = GameData.global_time_limit
	timer_bar.value = GameData.global_time_limit - GameData.global_time_elapsed
	countdown_timer.wait_time = 0.1
	countdown_timer.start()

	# Collega tutti i segnali via codice
	glass_menu_button.pressed.connect(_on_glass_menu_button_pressed)
	bottle_menu_button.pressed.connect(_on_bottle_menu_button_pressed)
	confirm_button.pressed.connect(_on_confirm_button_pressed)
	trash_button.pressed.connect(_on_trash_button_pressed)
	countdown_timer.timeout.connect(_on_timer_timeout)

	# Costruisce i menu con le immagini di bicchieri e bottiglie
	_build_glass_menu()
	_build_bottle_menu()

# -------------------------------------------------------
# Costruisce il menu bicchieri come popup a tutto schermo con griglia di TextureButton
func _build_glass_menu():
	for child in glass_menu.get_children():
		child.queue_free()

	# Sfondo scuro semitrasparente
	var bg = ColorRect.new()
	bg.size = Vector2(1152, 648)
	bg.color = Color(0, 0, 0, 0.7)
	glass_menu.add_child(bg)

	# Calcola posizione centrata per la griglia (4 bicchieri su una riga)
	var btn_size = 300
	var padding = 5
	var cols = 4
	var total_width = cols * btn_size + (cols - 1) * padding
	var start_x = (1152 - total_width) / 2
	var start_y = (648 - btn_size) / 2

	var i = 0
	for glass in GLASSES:
		var btn = TextureButton.new()
		btn.texture_normal = load(glass["sprite"])
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.size = Vector2(btn_size, btn_size)
		btn.position = Vector2(start_x + i * (btn_size + padding), start_y)
		glass_menu.add_child(btn)
		btn.pressed.connect(_on_glass_selected.bind(glass))
		i += 1

	# Bottone indietro in alto a sinistra
	var back_btn = TextureButton.new()
	back_btn.texture_normal = load("res://assets/ui/back_button.png")
	back_btn.ignore_texture_size = true
	back_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	back_btn.size = Vector2(80, 80)
	back_btn.position = Vector2(20, 20)
	glass_menu.add_child(back_btn)
	back_btn.pressed.connect(func(): glass_menu.visible = false)

# -------------------------------------------------------
# Costruisce il menu bottiglie come popup a tutto schermo con griglia 4x2
func _build_bottle_menu():
	for child in bottle_menu.get_children():
		child.queue_free()

	# Sfondo scuro semitrasparente
	var bg = ColorRect.new()
	bg.size = Vector2(1152, 648)
	bg.color = Color(0, 0, 0, 0.7)
	bottle_menu.add_child(bg)

	# Calcola posizione centrata per la griglia (4 colonne x 2 righe)
	var btn_size = 200
	var padding = 50
	var cols = 4
	var total_width = cols * btn_size + (cols - 1) * padding
	var total_height = 2 * btn_size + padding
	var start_x = (1152 - total_width) / 2
	var start_y = (648 - total_height) / 2

	var i = 0
	for bottle in BOTTLES:
		var btn = TextureButton.new()
		btn.texture_normal = load(bottle["sprite"])
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.size = Vector2(btn_size, btn_size)
		var col = i % cols
		var row = i / cols
		btn.position = Vector2(
			start_x + col * (btn_size + padding),
			start_y + row * (btn_size + padding)
		)
		bottle_menu.add_child(btn)
		btn.pressed.connect(_on_bottle_selected.bind(bottle))
		i += 1

	# Bottone indietro in alto a sinistra
	var back_btn = TextureButton.new()
	back_btn.texture_normal = load("res://assets/ui/back_button.png")
	back_btn.ignore_texture_size = true
	back_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	back_btn.size = Vector2(80, 80)
	back_btn.position = Vector2(20, 20)
	bottle_menu.add_child(back_btn)
	back_btn.pressed.connect(func(): bottle_menu.visible = false)

# -------------------------------------------------------
# Apre/chiude il menu bicchieri (chiude quello bottiglie se aperto)
func _on_glass_menu_button_pressed():
	glass_menu.visible = !glass_menu.visible
	bottle_menu.visible = false

# Apre/chiude il menu bottiglie (chiude quello bicchieri se aperto)
func _on_bottle_menu_button_pressed():
	bottle_menu.visible = !bottle_menu.visible
	glass_menu.visible = false

# -------------------------------------------------------
# Seleziona un bicchiere: resetta il drink e mostra lo sprite al centro
func _on_glass_selected(glass: Dictionary):
	glass_menu.visible = false
	selected_glass = glass

	# Rimuovi il bicchiere precedente se presente
	if glass_sprite:
		glass_sprite.queue_free()
		glass_sprite = null

	# Reset completo del drink
	poured_colors = []
	liquid_level = 0.0
	_clear_liquid()

	# Crea e mostra il nuovo sprite del bicchiere
	glass_sprite = Sprite2D.new()
	glass_sprite.texture = load(glass["sprite"])
	glass_sprite.position = Vector2(0, 0)
	glass_spot.add_child(glass_sprite)

	# Mostra i controlli rilevanti
	bottle_menu_button.visible = true
	trash_button.visible = true
	confirm_button.visible = false

# -------------------------------------------------------
# Seleziona una bottiglia: crea uno sprite da trascinare col mouse
func _on_bottle_selected(bottle: Dictionary):
	bottle_menu.visible = false

	# Non fare nulla se non è stato selezionato un bicchiere
	if selected_glass.is_empty():
		return

	dragging_bottle = bottle

	# Rimuovi eventuale sprite di trascinamento precedente
	if dragging_sprite:
		dragging_sprite.queue_free()

	# Crea lo sprite della bottiglia che segue il mouse
	dragging_sprite = Sprite2D.new()
	dragging_sprite.texture = load(bottle["sprite"])
	dragging_sprite.position = get_global_mouse_position()
	dragging_sprite.z_index = 10  # sopra tutto il resto
	add_child(dragging_sprite)
	is_dragging = true

# -------------------------------------------------------
func _process(_delta):
	# Aggiorna posizione dello sprite trascinato
	if is_dragging and dragging_sprite:
		dragging_sprite.position = get_global_mouse_position()

	# Aggiorna le particelle se si sta versando
	if is_pouring:
		_update_particles()

# -------------------------------------------------------
func _input(event):
	if is_dragging and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and !event.pressed:
			var mouse_pos = get_global_mouse_position()
			var glass_pos = glass_spot.global_position
			var distance = mouse_pos.distance_to(glass_pos)

			# Se il mouse è abbastanza vicino al bicchiere, versa il liquido
			if distance < 120:
				_start_pouring(dragging_bottle)

			# Rimuovi sempre lo sprite di trascinamento al rilascio
			if dragging_sprite:
				dragging_sprite.queue_free()
				dragging_sprite = null
			is_dragging = false

# -------------------------------------------------------
# Avvia l'animazione di versamento e aggiorna il livello del liquido
func _start_pouring(bottle: Dictionary):
	# Non versare se il bicchiere è già pieno
	if liquid_level >= max_liquid:
		return

	is_pouring = true

	# Aggiungi il colore alla lista solo se non già presente
	if bottle["name"] not in poured_colors:
		poured_colors.append(bottle["name"])

	# Avvia lo stream di particelle del colore della bottiglia
	_create_particle_stream(bottle["color"])

	# Anima l'aumento del livello del liquido
	var tween = create_tween()
	tween.tween_property(self, "liquid_level", min(liquid_level + 30.0, max_liquid), 1.0)
	await tween.finished

	is_pouring = false
	_clear_particles()
	_update_liquid_visual()

	# Mostra il bottone conferma appena c'è almeno un colore
	if poured_colors.size() > 0:
		confirm_button.visible = true

# -------------------------------------------------------
# Crea 15 particelle sopra il bicchiere che cadranno verso il basso
func _create_particle_stream(color: Color):
	_clear_particles()
	for i in range(15):
		var p = ColorRect.new()
		p.size = Vector2(6, 6)
		p.color = color
		# Le particelle partono sopra il bicchiere, distanziate verticalmente
		p.position = Vector2(randf_range(-5, 5), -150 - (i * 15))
		glass_spot.add_child(p)
		particle_stream.append(p)

# Sposta le particelle verso il basso, le nasconde quando raggiungono il bicchiere
func _update_particles():
	for p in particle_stream:
		if is_instance_valid(p):
			if p.position.y < 0:
				p.position.y += 4
			else:
				p.visible = false

# Rimuove tutte le particelle attive
func _clear_particles():
	for p in particle_stream:
		if is_instance_valid(p):
			p.queue_free()
	particle_stream.clear()

# -------------------------------------------------------
# Aggiorna il ColorRect che simula il liquido nel bicchiere
func _update_liquid_visual():
	var liquid = glass_spot.get_node_or_null("Liquid")
	if !liquid:
		liquid = ColorRect.new()
		liquid.name = "Liquid"
		glass_spot.add_child(liquid)

	var fill_ratio = liquid_level / max_liquid
	var w = selected_glass["liquid_width"]
	var h = selected_glass["liquid_height"]
	var offset_y = selected_glass["liquid_offset_y"]

	# Dimensione e posizione: il liquido sale dal basso verso l'alto
	liquid.size = Vector2(w, h * fill_ratio)
	liquid.position = Vector2(-w / 2, offset_y - h * fill_ratio + h)

	# Calcola il colore medio di tutti i liquidi versati
	if poured_colors.size() > 0:
		var mixed = Color(0, 0, 0)
		for c in poured_colors:
			for bottle in BOTTLES:
				if bottle["name"] == c:
					mixed += bottle["color"]
		mixed /= poured_colors.size()
		liquid.color = mixed

# Rimuove il ColorRect del liquido
func _clear_liquid():
	var liquid = glass_spot.get_node_or_null("Liquid")
	if liquid:
		liquid.queue_free()

# -------------------------------------------------------
# Svuota il bicchiere e resetta tutto per ricominciare
func _on_trash_button_pressed():
	poured_colors = []
	liquid_level = 0.0
	_clear_liquid()
	_clear_particles()
	confirm_button.visible = false

# -------------------------------------------------------
# Conferma il drink: salva i colori in GameData e torna al bancone
func _on_confirm_button_pressed():
	countdown_timer.stop()
	GameData.prepared_drink = poured_colors.duplicate()
	GameData.returning_from_preparation = true
	get_tree().change_scene_to_file("res://scenes/bartender_scene.tscn")

# -------------------------------------------------------
func _on_timer_timeout():
	# Aggiorna sia il tempo dell'ordine che quello della giornata
	GameData.day_time_elapsed += 0.1
	GameData.global_time_elapsed += 0.1
	var time_left = GameData.global_time_limit - GameData.global_time_elapsed
	timer_bar.value = time_left

	# Cambia colore della barra in base al tempo rimasto
	var ratio = time_left / GameData.global_time_limit
	var bar_color: Color
	if ratio > 0.7:
		bar_color = Color(0.2, 0.8, 0.2)    # verde: tempo abbondante
	elif ratio > 0.3:
		bar_color = Color(0.9, 0.7, 0.1)    # giallo: tempo che scarseggia
	else:
		bar_color = Color(0.9, 0.1, 0.1)    # rosso: tempo quasi finito
	var style = StyleBoxFlat.new()
	style.bg_color = bar_color
	timer_bar.add_theme_stylebox_override("fill", style)

	# Tempo scaduto: segna come scaduto e torna al bancone
	if time_left <= 0:
		countdown_timer.stop()
		GameData.timer_running = false
		GameData.prepared_drink = []
		GameData.time_expired = true
		GameData.returning_from_preparation = true
		get_tree().change_scene_to_file("res://scenes/bartender_scene.tscn")
