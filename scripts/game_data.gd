extends Node

# --- ORDINE E DRINK ---
var current_order: Array = []              # colori dell'ordine del cliente attuale
var prepared_drink: Array = []             # colori del drink preparato da Andrea
var current_customer_data: Dictionary = {} # dati del cliente attuale (sopravvive al cambio scena)
var returning_from_preparation: bool = false  # true se stiamo tornando dalla scena di Andrea
var time_expired: bool = false             # true se il tempo è scaduto durante la preparazione

# --- TIMER GLOBALE ORDINE ---
var global_time_limit: float = 30.0       # tempo massimo per completare l'ordine (in secondi)
var global_time_elapsed: float = 0.0      # tempo trascorso dall'accettazione dell'ordine
var timer_running: bool = false            # true se il timer dell'ordine è attivo

# --- SOLDI ---
var money: float = 0.0                    # soldi attuali del giocatore
var goal: float = 350000.0               # obiettivo per vincere
var current_drink_value: float = 0.0      # valore del drink del cliente attuale

# --- STATISTICHE ---
var customers_satisfied: int = 0          # totale clienti soddisfatti
var customers_failed: int = 0             # totale clienti insoddisfatti
var failed_streak: int = 0               # clienti falliti consecutivi (3 = game over)

# --- GIORNATA ---
var current_day: int = 1                  # giorno corrente
var day_duration: float = 120.0          # durata reale di una giornata in secondi (2 minuti)
var day_time_elapsed: float = 0.0        # tempo trascorso nella giornata corrente
var day_active: bool = false             # true se la giornata è in corso
var game_over: bool = false              # true se il gioco è finito

# --- PAZIENZA: moltiplicatore per giornata ---
# Giorno 1: pazienza piena, giorno 6: solo 20% — diventa sempre più difficile
const PATIENCE_MULTIPLIERS = [1.0, 0.85, 0.7, 0.55, 0.35, 0.2]

# --- CLIENTI PER GIORNATA: intervallo (min, max) ---
# Il numero di clienti aumenta ogni giorno, il giorno 6 è la sfida finale
const DAILY_CUSTOMERS = [
	[4, 6],    # giorno 1
	[5, 7],    # giorno 2
	[6, 8],    # giorno 3
	[7, 9],    # giorno 4
	[8, 11],   # giorno 5
	[10, 14],  # giorno 6 — massimo clienti, minima pazienza
]

var max_customers_today: int = 0          # numero massimo di clienti per la giornata corrente
var customers_served_today: int = 0       # clienti già serviti oggi

# -------------------------------------------------------
# Restituisce il moltiplicatore di pazienza per il giorno corrente
func get_patience_multiplier() -> float:
	var index = min(current_day - 1, PATIENCE_MULTIPLIERS.size() - 1)
	return PATIENCE_MULTIPLIERS[index]

# -------------------------------------------------------
# Inizializza una nuova giornata: calcola clienti massimi e resetta i contatori
func setup_new_day():
	var index = min(current_day - 1, DAILY_CUSTOMERS.size() - 1)
	var day_range = DAILY_CUSTOMERS[index]  # rinominato da "range" per evitare conflitto con funzione built-in
	max_customers_today = randi_range(day_range[0], day_range[1])
	customers_served_today = 0
	day_time_elapsed = 0.0
	day_active = true
