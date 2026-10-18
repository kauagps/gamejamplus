extends Node2D

# Distância (em pixels) que a prévia fica à frente do jogador
const DISTANCIA_CONSTRUCAO: float = 32.0

# Receitas: o que cada construção custa.
# "custo" usa os MESMOS nomes que os itens do inventário.
const RECEITAS: Dictionary = {
	"fogueira": {
		"nome": "Fogueira",
		"cena": preload("res://cenas/Fogueira.tscn"),
		"custo": ["madeira", "madeira"],
	},
	"abrigo": {
		"nome": "Abrigo",
		"cena": preload("res://cenas/Abrigo.tscn"),
		"custo": ["madeira", "madeira", "pedra"],
	},
}

@onready var timer: Timer = $TimerDiaNoite
@onready var modulacao: CanvasModulate = $LuzGlobal
@onready var hud: CanvasLayer = $HUD
@onready var node_construcoes: Node2D = $Node  # nó com y_sort_enabled
@onready var jogador: Node2D = get_tree().get_first_node_in_group("jogador")

var e_noite: bool = false
var dia_atual: int = 1  # o dia atual do jogo (começa no DIA 1)

# --- Modo de construção ---
var construcao_ativa: String = ""  # "" = nenhum modo ativo
var fantasma: Node2D = null        # prévia semi-transparente da construção

func _ready() -> void:
	timer.timeout.connect(_alternar_dia_noite)
	timer.start()

	if jogador == null:
		push_error("Main: não achei o Player no grupo 'jogador'!")

	hud.construcao_solicitada.connect(_on_construcao_solicitada)

func _process(_delta: float) -> void:
	# --- Modo de construção: a prévia (fantasma) segue o jogador ---
	if fantasma != null:
		# O fantasma fica sempre um pouco à frente do jogador
		fantasma.global_position = jogador.global_position + jogador.ultima_direcao * DISTANCIA_CONSTRUCAO

		# E confirma, Esc cancela
		if Input.is_action_just_pressed("interagir"):
			_confirmar_construcao()
		elif Input.is_action_just_pressed("ui_cancel"):
			_cancelar_construcao()

# =====================================================================
# CONSTRUÇÃO
# =====================================================================
func _on_construcao_solicitada(tipo: String) -> void:
	if not RECEITAS.has(tipo):
		push_error("Main: receita desconhecida: " + tipo)
		return

	_cancelar_construcao()  # se já havia um fantasma, descarta ele

	var receita: Dictionary = RECEITAS[tipo]
	if not jogador.tem_itens(receita["custo"]):
		hud.mostrar_aviso("Faltam materiais para " + receita["nome"] + "!")
		return

	var cena: PackedScene = receita["cena"]
	fantasma = cena.instantiate()
	fantasma.modulate.a = 0.5  # semi-transparente = "ainda não construído"
	if fantasma is CollisionObject2D:
		fantasma.collision_layer = 0  # fantasma não bloqueia o jogador

	node_construcoes.add_child(fantasma)
	construcao_ativa = tipo
	jogador.modo_construcao = true  # impede que o E pegue item enquanto constrói

func _confirmar_construcao() -> void:
	if fantasma == null:
		return

	var receita: Dictionary = RECEITAS[construcao_ativa]
	if not jogador.consumir_itens(receita["custo"]):
		# Não deveria acontecer (checamos ao entrar no modo), mas é seguro
		hud.mostrar_aviso("Faltam materiais!")
		_cancelar_construcao()
		return

	# A prévia vira construção de verdade
	fantasma.modulate.a = 1.0
	if fantasma is CollisionObject2D:
		fantasma.collision_layer = 1
	fantasma = null
	construcao_ativa = ""

	# Espera o próximo frame de física pra liberar o E, senão o MESMO toque
	# que confirmou a construção também pegaria um item no mesmo frame
	await get_tree().physics_frame
	jogador.modo_construcao = false

func _cancelar_construcao() -> void:
	if fantasma:
		fantasma.queue_free()
		fantasma = null
	construcao_ativa = ""
	if jogador:
		jogador.modo_construcao = false

# =====================================================================
# CICLO DIA / NOITE
# =====================================================================
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
	# Só dá pra dormir de noite
	if not e_noite:
		hud.mostrar_aviso("Você só pode dormir à noite!")
		return

	# Amanhece na hora. Como o timer é reiniciado, o próximo anoitecer
	# só vem um "dia" (timeout) inteiro depois.
	e_noite = false
	modulacao.color = Color(1, 1, 1)
	timer.stop()
	timer.start()

	# Dormir avança para o dia seguinte
	dia_atual += 1
	hud.atualizar_contador_dias(dia_atual)

	# Acorda descansado: sanidade cheia
	# (mudar_sanidade SOMA e faz clamp, então passar o máximo devolve tudo)
	Status.mudar_sanidade(Status.sanidade_maximo)
