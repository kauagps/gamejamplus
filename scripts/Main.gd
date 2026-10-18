extends Node2D

@onready var timer: Timer = $TimerDiaNoite
@onready var modulacao: CanvasModulate = $LuzGlobal
@onready var hud: CanvasLayer = $HUD

var e_noite: bool = false
var dia_atual: int = 1  # o dia atual do jogo (começa no DIA 1)

func _ready() -> void:
	timer.timeout.connect(_alternar_dia_noite)
	timer.start()
	Status.mudar_fome(-30.0)
	
func _alternar_dia_noite() -> void:
	e_noite = not e_noite
	
	if e_noite:
		modulacao.color = Color(0.2, 0.2, 0.4)
	else:
		modulacao.color = Color(1, 1, 1)
		# Amanheceu -> virou o dia: conta +1 e atualiza o contador do HUD
		dia_atual += 1
		hud.atualizar_contador_dias(dia_atual)
		
	timer.start()
	
func dormir() -> void:
	e_noite = false
	modulacao.color = Color(1, 1, 1)
	timer.stop()
	timer.start()
	# Dormir também avança para o dia seguinte
	dia_atual += 1
	hud.atualizar_contador_dias(dia_atual)
