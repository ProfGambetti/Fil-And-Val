extends Node2D

# --- DATI CLIENTI ---
const CUSTOMERS = [
	{ "name": "Doraemon", "sprite": "res://assets/customers/doraemon.png", "patience": 50.0 },
	{ "name": "UncleGrandpa",  "sprite": "res://assets/customers/u_g.png",  "patience": 65.0 },
	{ "name": "Darwin",  "sprite": "res://assets/customers/darwin.png",  "patience": 55.0 },
]

# --- COLORI DISPONIBILI ---
const COLORS = ["rosso", "blu", "verde", "giallo", "viola", "arancione"]

# --- RIFERIMENTI AI NODI ---
@onready var order_label: Label = $UI/OrderPanel/OrderLabel
@onready var timer_bar: ProgressBar = $UI/TimerBar
@onready var accept_button: Button = $UI/AcceptButton
@onready var deliver_button: Button = $UI/DeliverButton
@onready var result_label: Label = $UI/ResultLabel
@onready var countdown_timer: Timer = $Timer
@onready var customer_spot: Node2D = $CustomerSpot

# --- VARIABILI DI STATO ---
var current_customer: Dictionary = {}
var current_order: Array = []
var time_left: float = 0.0
var waiting_for_delivery: bool = false
var customer_sprite: Sprite2D = null

# -------------------------------------------------------
func _ready():
	deliver_button.visible = false
	result_label.visible = false
	accept_button.visible = false
	
	# Collega i segnali via codice
	accept_button.pressed.connect(_on_accept_button_pressed)
	deliver_button.pressed.connect(_on_deliver_button_pressed)
	
	countdown_timer.timeout.connect(_on_timer_timeout)
	
	deliver_button.visible = false
	result_label.visible = false
	accept_button.visible = false

	if GameData.returning_from_preparation:
		GameData.returning_from_preparation = false
		current_customer = GameData.current_customer_data
		current_order = GameData.current_order
		order_label.text = "Ordine: " + ", ".join(current_order)
		_return_from_preparation()
	else:
		spawn_next_customer()

# -------------------------------------------------------
func spawn_next_customer():
	result_label.visible = false
	deliver_button.visible = false
	waiting_for_delivery = false

	# Cliente random
	current_customer = CUSTOMERS[randi() % CUSTOMERS.size()]

	# Ordine random (2 o 3 colori)
	var shuffled = COLORS.duplicate()
	shuffled.shuffle()
	var count = randi_range(2, 3)
	current_order = shuffled.slice(0, count)

	# Mostra ordine
	order_label.text = "Ordine: " + ", ".join(current_order)

	# Crea sprite cliente
	customer_sprite = Sprite2D.new()
	customer_sprite.texture = load(current_customer["sprite"])
	customer_spot.add_child(customer_sprite)
	customer_sprite.scale = Vector2(2.0, 2.0)

	# Animazione entrata da sinistra
	customer_sprite.position = Vector2(1200, 300)
	var tween = create_tween()
	tween.tween_property(customer_sprite, "position", Vector2(100, 150), 1.2).set_ease(Tween.EASE_OUT)
	await tween.finished

	# Mostra bottone accetta e avvia timer
	accept_button.visible = true
	_start_timer(current_customer["patience"])

# -------------------------------------------------------
func _return_from_preparation():
	waiting_for_delivery = true
	deliver_button.visible = true

	# Ricrea sprite (la scena è stata ricaricata)
	customer_sprite = Sprite2D.new()
	customer_sprite.texture = load(current_customer["sprite"])
	customer_sprite.position = Vector2(0, 0)
	customer_spot.add_child(customer_sprite)

	# Timer più corto per la consegna
	_start_timer(current_customer["patience"] / 2.0)

# -------------------------------------------------------
func _start_timer(duration: float):
	time_left = duration
	timer_bar.max_value = duration
	timer_bar.value = duration
	countdown_timer.wait_time = 0.1
	countdown_timer.start()

# -------------------------------------------------------
func _on_accept_button_pressed():
	accept_button.visible = false
	countdown_timer.stop()

	# Salva tutto in GameData prima di cambiare scena
	GameData.current_order = current_order
	GameData.current_customer_data = current_customer
	GameData.prepared_drink = []

	# Vai alla scena di Andrea
	get_tree().change_scene_to_file("res://scenes/preparation_scene.tscn")

# -------------------------------------------------------
func _on_deliver_button_pressed():
	countdown_timer.stop()
	deliver_button.visible = false

	var success = _check_drink()
	_show_result(success)

	await get_tree().create_timer(2.5).timeout
	_clear_customer()
	spawn_next_customer()

# -------------------------------------------------------
func _check_drink() -> bool:
	var prepared = GameData.prepared_drink.duplicate()
	var ordered = current_order.duplicate()
	prepared.sort()
	ordered.sort()
	return prepared == ordered

# -------------------------------------------------------
func _show_result(success: bool):
	result_label.visible = true
	if success:
		result_label.text = "Cliente soddisfatto! 😄"
		result_label.modulate = Color.GREEN
	else:
		result_label.text = "Cliente deluso... 😞"
		result_label.modulate = Color.RED

# -------------------------------------------------------
func _clear_customer():
	for child in customer_spot.get_children():
		child.queue_free()

# -------------------------------------------------------
func _on_timer_timeout():
	time_left -= 0.1
	timer_bar.value = time_left

	if time_left <= 0:
		countdown_timer.stop()
		accept_button.visible = false
		deliver_button.visible = false

		result_label.visible = true
		result_label.text = "Il cliente è andato via! ⏰"
		result_label.modulate = Color.ORANGE

		await get_tree().create_timer(2.5).timeout
		_clear_customer()
		spawn_next_customer()
