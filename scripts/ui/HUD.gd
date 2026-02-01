extends CanvasLayer

@onready var _label_puntuacion: Label = $MarginContainer/VBoxContainer/LabelPuntuacion

func _ready() -> void:
	Global.puntuacion_cambiada.connect(_on_puntuacion_cambiada)
	_actualizar_texto_puntuacion()

func _on_puntuacion_cambiada(_id_jugador: int, _nueva_puntuacion: int) -> void:
	_actualizar_texto_puntuacion()

func _actualizar_texto_puntuacion() -> void:
	var p1 := Global.obtener_puntuacion(1)
	var p2 := Global.obtener_puntuacion(2)
	var objetivo := Global.puntos_ganar
	_label_puntuacion.text = "J1: %d | J2: %d | Objetivo: %d" % [p1, p2, objetivo]
