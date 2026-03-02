extends Node

# Ordine corrente (Filippo lo scrive, Andrea lo legge)
var current_order: Array = []

# Drink preparato (Andrea lo scrive, Filippo lo legge)
var prepared_drink: Array = []

# Cliente attivo salvato (per sopravvivere al cambio scena)
var current_customer_data: Dictionary = {}

# Flag: stiamo tornando dalla preparazione di Andrea?
var returning_from_preparation: bool = false
