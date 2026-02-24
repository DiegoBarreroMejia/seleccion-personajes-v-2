extends Control

@onready var _btn_reanudar: TextureButton = $Marco/ContenedorCentral/BtnReanudar

# Configura process mode y da foco al boton reanudar
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_btn_reanudar.grab_focus()

# Reanuda la partida
func _on_btn_reanudar_pressed() -> void:
	PauseManager.reanudar()

# Abre los ajustes como overlay
func _on_btn_ajustes_pressed() -> void:
	PauseManager.abrir_ajustes()

# Sale al menu principal
func _on_btn_salir_pressed() -> void:
	PauseManager.salir_al_menu()
