extends Control

## Menú de pausa que aparece durante el juego
##
## Permite reanudar la partida o salir al menú principal.
## Se instancia y destruye dinámicamente por PauseManager.

# === NODOS ===
@onready var _btn_reanudar: Button = $Panel/ContenedorCentral/BtnReanudar

# === MÉTODOS DE CICLO DE VIDA ===

func _ready() -> void:
	# Permite procesar incluso cuando el juego está pausado
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Dar foco al primer botón para navegación con teclado
	_btn_reanudar.grab_focus()

# === SEÑALES DE BOTONES ===

func _on_btn_reanudar_pressed() -> void:
	PauseManager.reanudar()

func _on_btn_salir_pressed() -> void:
	PauseManager.salir_al_menu()
