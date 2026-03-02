extends Node2D

# --- DATI CLIENTI: lista di tutti i clienti possibili ---
const CUSTOMERS = [
	{ "name": "Doraemon", "sprite": "res://assets/customers/doraemon.png", "patience": 50.0 },
	{ "name": "UncleGrandpa", "sprite": "res://assets/customers/u_g.png", "patience": 65.0 },
	{ "name": "Darwin", "sprite": "res://assets/customers/darwin.png", "patience": 55.0 },
]

# --- COLORI DISPONIBILI per gli ordini ---
const COLORS = ["rosso", "blu", "verde", "giallo", "viola", "arancione", "celeste", "rosa"]

# --- RIFERIMENTI AI NODI della scena ---
@onready var order_label: Label = $UI/OrderPanel/OrderLabel         # mostra l'ordine del cliente
@onready var timer_bar: ProgressBar = $UI/TimerBar                  # barra del tempo rimasto
@onready var accept_button: Button = $UI/AcceptButton               # bottone per accettare l'ordine
@onready var deliver_button: Button = $UI/DeliverButton             # bottone per consegnare il drink
@onready var countdown_timer: Timer = $Timer                        # timer che fa tick ogni 0.1s
@onready var customer_spot: Node2D = $CustomerSpot                  # punto dove appare il cliente
@onready var overlay: ColorRect = $UI/Overlay                       # sfondo scuro dei popup
@onready var result_popup: Panel = $UI/ResultPopup                  # pannello popup risultato
@onready var result_popup_label: Label = $UI/ResultPopup/ResultPopupLabel  # testo del popup
@onready var money_label: Label = $UI/MoneyLabel                    # mostra i soldi attuali
@onready var clock_label: Label = $UI/ClockLabel                    # mostra l'orario della giornata
@onready var day_label: Label = $UI/DayLabel                        # mostra il giorno corrente

# --- VARIABILI DI STATO ---
var current_customer: Dictionary = {}      # dati del cliente attuale
var current_order: Array = []              # colori dell'ordine attuale
var waiting_for_delivery: bool = false     # true se stiamo aspettando la consegna del drink
var customer_sprite: Sprite2D = null       # sprite del cliente attuale
var day_ending: bool = false               # flag per evitare che _end_day venga chiamata più volte

# -------------------------------------------------------
func _ready():
	# Nascondi elementi UI all'avvio
	deliver_button.visible = false
	accept_button.visible = false
	overlay.visible = false
	result_popup.visible = false

	# Collega i segnali dei bottoni e del timer via codice
	accept_button.pressed.connect(_on_accept_button_pressed)
	deliver_button.pressed.connect(_on_deliver_button_pressed)
	countdown_timer.timeout.connect(_on_timer_timeout)

	# Imposta colore iniziale della progress bar (verde)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.8, 0.2)
	timer_bar.add_theme_stylebox_override("fill", style)

	# Se stiamo tornando dalla scena di preparazione, ripristina lo stato
	if GameData.returning_from_preparation:
		GameData.returning_from_preparation = false
		current_customer = GameData.current_customer_data
		current_order = GameData.current_order
		order_label.text = "Ordine: " + ", ".join(current_order)
		day_label.text = "Giorno %d" % GameData.current_day
		money_label.text = "€ %s" % str(int(GameData.money))
		_return_from_preparation()
	else:
		# Primo avvio: inizializza la giornata e spawna il primo cliente
		GameData.setup_new_day()
		day_label.text = "Giorno %d" % GameData.current_day
		spawn_next_customer()

# -------------------------------------------------------
func spawn_next_customer():
	# Blocca se il gioco è finito
	if GameData.game_over:
		return

	# Controlla se il numero massimo di clienti per oggi è stato raggiunto
	if GameData.customers_served_today >= GameData.max_customers_today:
		_end_day()
		return

	# Incrementa il contatore clienti della giornata
	GameData.customers_served_today += 1

	# Reset stato consegna
	deliver_button.visible = false
	waiting_for_delivery = false

	# Scegli un cliente a caso dalla lista
	current_customer = CUSTOMERS[randi() % CUSTOMERS.size()]

	# Genera un ordine random con 2 o 3 colori
	var shuffled = COLORS.duplicate()
	shuffled.shuffle()
	var count = randi_range(2, 3)
	current_order = shuffled.slice(0, count)
	order_label.text = "Ordine: " + ", ".join(current_order)

	# Crea e posiziona lo sprite del cliente fuori dallo schermo a destra
	customer_sprite = Sprite2D.new()
	customer_sprite.texture = load(current_customer["sprite"])
	customer_sprite.scale = Vector2(2.0, 2.0)
	customer_sprite.position = Vector2(1200, 300)
	customer_spot.add_child(customer_sprite)

	# Animazione entrata: il cliente scivola verso il suo posto
	var tween = create_tween()
	tween.tween_property(customer_sprite, "position", Vector2(100, 150), 1.2).set_ease(Tween.EASE_OUT)
	await tween.finished

	# Mostra il bottone per accettare l'ordine
	accept_button.visible = true

	# Avvia il timer globale con la pazienza del cliente modificata dal giorno corrente
	GameData.global_time_elapsed = 0.0
	GameData.global_time_limit = current_customer["patience"] * GameData.get_patience_multiplier()
	GameData.timer_running = true
	countdown_timer.wait_time = 0.1
	countdown_timer.start()

	# Genera il valore economico del drink per questo cliente
	GameData.current_drink_value = randf_range(3000.0, 15000.0)

# -------------------------------------------------------
func _return_from_preparation():
	# Se il tempo è scaduto durante la preparazione, mostra risultato negativo
	if GameData.time_expired:
		GameData.time_expired = false
		_show_result(false)
		await get_tree().create_timer(2.5).timeout
		await _clear_customer()
		spawn_next_customer()
		return

	# Altrimenti, mostra il cliente e aspetta la consegna
	waiting_for_delivery = true
	deliver_button.visible = true

	# Ricrea lo sprite del cliente (la scena è stata ricaricata)
	customer_sprite = Sprite2D.new()
	customer_sprite.texture = load(current_customer["sprite"])
	customer_sprite.position = Vector2(100, 150)
	customer_sprite.scale = Vector2(2.0, 2.0)
	customer_spot.add_child(customer_sprite)

	# Riavvia il timer (il tempo continua da dove era rimasto in GameData)
	countdown_timer.wait_time = 0.1
	countdown_timer.start()

# -------------------------------------------------------
func _on_accept_button_pressed():
	accept_button.visible = false
	countdown_timer.stop()  # ferma il tick locale, il tempo continua tracciato in GameData

	# Salva i dati necessari in GameData prima di cambiare scena
	GameData.current_order = current_order
	GameData.current_customer_data = current_customer
	GameData.prepared_drink = []

	# Vai alla scena di preparazione
	get_tree().change_scene_to_file("res://scenes/preparation_scene.tscn")

# -------------------------------------------------------
func _on_deliver_button_pressed():
	countdown_timer.stop()
	deliver_button.visible = false

	# Controlla se il drink corrisponde all'ordine
	var success = _check_drink()
	_show_result(success)

	await get_tree().create_timer(2.5).timeout
	await _clear_customer()
	spawn_next_customer()

# -------------------------------------------------------
func _check_drink() -> bool:
	# Confronta i colori del drink preparato con quelli dell'ordine (ordinati)
	var prepared = GameData.prepared_drink.duplicate()
	var ordered = current_order.duplicate()
	prepared.sort()
	ordered.sort()
	return prepared == ordered

# -------------------------------------------------------
func _show_result(success: bool):
	# Mostra overlay scuro e popup risultato
	overlay.visible = true
	result_popup.visible = true
	var tween = create_tween()
	tween.tween_property(overlay, "color", Color(0, 0, 0, 0.6), 0.3)

	if success:
		# Cliente soddisfatto: aggiungi soldi e resetta la striscia negativa
		GameData.money += GameData.current_drink_value
		GameData.customers_satisfied += 1
		GameData.failed_streak = 0
		result_popup_label.text = "Cliente soddisfatto! \n+ € %s" % str(int(GameData.current_drink_value))
		result_popup.modulate = Color(0.2, 0.9, 0.2)

		# Controlla se si è raggiunto l'obiettivo
		if GameData.money >= GameData.goal:
			await get_tree().create_timer(1.0).timeout
			_show_victory()
			return
	else:
		# Cliente insoddisfatto: scala soldi e incrementa la striscia negativa
		GameData.money -= GameData.current_drink_value
		GameData.customers_failed += 1
		GameData.failed_streak += 1
		result_popup_label.text = "Cliente deluso... \n- € %s" % str(int(GameData.current_drink_value))
		result_popup.modulate = Color(0.9, 0.2, 0.2)

		# Controlla se si è raggiunto il limite di errori consecutivi
		if GameData.failed_streak >= 3:
			await get_tree().create_timer(1.0).timeout
			_show_game_over()
			return

	# Chiudi il popup dopo 2.5 secondi
	await get_tree().create_timer(2.5).timeout
	var tween2 = create_tween()
	tween2.tween_property(overlay, "color", Color(0, 0, 0, 0), 0.3)
	await tween2.finished
	overlay.visible = false
	result_popup.visible = false

# -------------------------------------------------------
func _clear_customer():
	# Anima l'uscita del cliente verso il basso, poi rimuove tutti i figli di customer_spot
	if customer_sprite and is_instance_valid(customer_sprite):
		var tween = create_tween()
		tween.tween_property(customer_sprite, "position", Vector2(customer_sprite.position.x, 600), 0.8).set_ease(Tween.EASE_IN)
		await tween.finished
	for child in customer_spot.get_children():
		child.queue_free()
	customer_sprite = null

# -------------------------------------------------------
func _on_timer_timeout():
	if !GameData.timer_running:
		return

	# Aggiorna il tempo trascorso e calcola il tempo rimasto
	GameData.global_time_elapsed += 0.1
	var time_left = GameData.global_time_limit - GameData.global_time_elapsed
	timer_bar.max_value = GameData.global_time_limit
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

	# Tempo scaduto: il cliente se ne va insoddisfatto
	if time_left <= 0:
		countdown_timer.stop()
		GameData.timer_running = false
		accept_button.visible = false
		deliver_button.visible = false
		_show_result(false)
		await get_tree().create_timer(2.5).timeout
		await _clear_customer()
		spawn_next_customer()

# -------------------------------------------------------
func _process(delta):
	if !GameData.day_active:
		return

	# Avanza il tempo della giornata
	GameData.day_time_elapsed += delta
	var time_left = GameData.day_duration - GameData.day_time_elapsed

	# Aggiorna orologio: la giornata va dalle 18:00 alle 23:00 (5 ore = 300 minuti di gioco)
	var minutes_passed = (GameData.day_time_elapsed / GameData.day_duration) * 300
	var hour = 18 + int(minutes_passed / 60)
	var minute = int(minutes_passed) % 60
	clock_label.text = "%02d:%02d" % [hour, minute]

	# Aggiorna la label dei soldi ad ogni frame
	money_label.text = "€ %s" % str(int(GameData.money))

	# Controlla se la giornata è finita per tempo
	if time_left <= 0 and GameData.day_active:
		_end_day()

# -------------------------------------------------------
func _end_day():
	# Evita chiamate multiple con il flag day_ending
	if day_ending:
		return
	day_ending = true
	GameData.day_active = false
	countdown_timer.stop()
	accept_button.visible = false
	deliver_button.visible = false

	# Mostra popup fine giornata con riepilogo soldi
	overlay.visible = true
	result_popup.visible = true
	var tween = create_tween()
	tween.tween_property(overlay, "color", Color(0, 0, 0, 0.8), 0.3)
	result_popup_label.text = "Giornata %d finita!\n€ %s" % [GameData.current_day, str(int(GameData.money))]
	result_popup.modulate = Color(1, 1, 1)

	# Aggiunge dinamicamente il bottone per passare al giorno successivo
	var next_btn = Button.new()
	next_btn.text = "Vai alla giornata successiva →"
	next_btn.size = Vector2(300, 50)
	next_btn.position = Vector2(100, 140)
	result_popup.add_child(next_btn)
	next_btn.pressed.connect(_on_next_day_pressed)

# -------------------------------------------------------
func _on_next_day_pressed():
	day_ending = false

	# Rimuovi il bottone dal popup prima di chiuderlo
	for child in result_popup.get_children():
		if child is Button:
			child.queue_free()

	overlay.visible = false
	result_popup.visible = false

	# Avanza al giorno successivo e resetta la striscia negativa
	GameData.current_day += 1
	GameData.failed_streak = 0
	GameData.setup_new_day()

	# Aggiorna la label del giorno e spawna il primo cliente della nuova giornata
	day_label.text = "Giorno %d" % GameData.current_day
	await _clear_customer()
	spawn_next_customer()

# -------------------------------------------------------
func _show_game_over():
	GameData.game_over = true
	overlay.visible = true
	result_popup.visible = true
	result_popup.size = Vector2(500, 350)
	result_popup.position = Vector2(326, 150)
	result_popup.modulate = Color(1, 1, 1)
	result_popup_label.text = (
		"GAME OVER\n\n" +
		"💰 € %s\n" % str(int(GameData.money)) +
		"😄 Soddisfatti: %d\n" % GameData.customers_satisfied +
		"😞 Insoddisfatti: %d\n" % GameData.customers_failed +
		"📅 Giornate: %d" % GameData.current_day
	)
	var tween = create_tween()
	tween.tween_property(overlay, "color", Color(0, 0, 0, 0.8), 0.3)

	# Bottone ricomincia rosa con testo bianco
	var restart_btn = Button.new()
	restart_btn.text = "Ricomincia"
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.4, 0.7)
	restart_btn.add_theme_stylebox_override("normal", style)
	restart_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	restart_btn.size = Vector2(200, 50)
	restart_btn.position = Vector2(150, 285)
	result_popup.add_child(restart_btn)
	restart_btn.pressed.connect(_on_restart_pressed)

# -------------------------------------------------------
func _show_victory():
	GameData.game_over = true
	overlay.visible = true
	result_popup.visible = true
	result_popup.size = Vector2(500, 350)
	result_popup.position = Vector2(326, 150)
	result_popup.modulate = Color(1, 0.9, 0.1)
	result_popup_label.text = (
		"HAI VINTO! 🎉\n\n" +
		"💰 € %s\n" % str(int(GameData.money)) +
		"😄 Soddisfatti: %d\n" % GameData.customers_satisfied +
		"😞 Insoddisfatti: %d\n" % GameData.customers_failed +
		"📅 Giornate: %d" % GameData.current_day
	)
	var tween = create_tween()
	tween.tween_property(overlay, "color", Color(0, 0, 0, 0.8), 0.3)

	# Bottone ricomincia rosa con testo bianco
	var restart_btn = Button.new()
	restart_btn.text = "Ricomincia"
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.4, 0.7)
	restart_btn.add_theme_stylebox_override("normal", style)
	restart_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	restart_btn.size = Vector2(200, 50)
	restart_btn.position = Vector2(150, 285)
	result_popup.add_child(restart_btn)
	restart_btn.pressed.connect(_on_restart_pressed)

# -------------------------------------------------------
func _on_restart_pressed():
	# Reset completo di tutti i dati di GameData
	GameData.game_over = false
	GameData.money = 0.0
	GameData.customers_satisfied = 0
	GameData.customers_failed = 0
	GameData.failed_streak = 0
	GameData.current_day = 1
	GameData.day_time_elapsed = 0.0
	GameData.day_active = true
	GameData.returning_from_preparation = false
	get_tree().reload_current_scene()
