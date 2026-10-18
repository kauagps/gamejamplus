extends Node2D

# Distância (em pixels) que a prévia fica à frente do jogador
const DISTANCIA_CONSTRUCAO: float = 32.0

# --- FOME ---
# Quanto da barra de fome o jogador perde por dia (em pontos).
# 100 = a barra inteira em um dia, que foi o que você escolheu.
# Como a conta abaixo usa a duração REAL do dia (TimerDiaNoite), mudar o
# wait_time do timer no Inspector já ajusta a velocidade da fome sozinho.
const FOME_POR_DIA: float = 100.0

# Quanto de sanidade cai por dia quando a fome está zerada
const SANIDADE_POR_DIA_SEM_COMIDA: float = 50.0

# Quanto de fome dormir custa (1/4 do consumo de um dia inteiro)
const FOME_PERDIDA_AO_DORMIR: float = FOME_POR_DIA * 0.25

# --- NOITE (um PRAZO, não mais um relógio) ---
# A noite não passa sozinha: ela só termina quando o jogador dorme.
# Enquanto isso a sanidade escorre, e é isso que empurra ele pra cama.
# 100 = a barra inteira se esvazia em um dia de noite (escolha do time).
const SANIDADE_POR_DIA_NA_NOITE: float = 100.0

# --- LUZ DO DIA ---
# Onde o "momento do dia" (0.0 a 1.0 do gradiente) para em cada marco.
const PONTO_ANOITECER: float = 0.5        # fim do dia: o céu começa a fechar
const PONTO_NOITE: float = 0.85           # a cor plana da noite no gradiente
const DURACAO_DO_ANOITECER: float = 4.0   # segundos até o céu fechar de vez

# --- PENSAMENTOS DO PERSONAGEM ---
# "momento" = fração do DIA (0.5 = metade do dia, 0.9 = faltando 10%).
# São os avisos de que a noite vem vindo. Como são PORCENTAGEM, mudar a
# duração do dia no Inspector não desalinha eles.
const PENSAMENTOS_DO_DIA: Array = [
	{ "momento": 0.50, "texto": "O sol está baixando..." },
	{ "momento": 0.75, "texto": "Tá escurecendo, melhor eu achar a casa." },
	{ "momento": 0.90, "texto": "Está anoitecendo, preciso dormir." },
]

# De quanto em quanto tempo ele repete que precisa dormir, de noite
const INTERVALO_PENSAMENTO_NOITE: float = 8.0

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
@onready var modulacao: LuzGlobal = $LuzGlobal
@onready var hud: CanvasLayer = $HUD
@onready var vinheta: Vinheta = $Vinheta
@onready var node_construcoes: Node2D = $Node  # nó com y_sort_enabled
@onready var jogador: Node2D = get_tree().get_first_node_in_group("jogador")

var e_noite: bool = false
var dia_atual: int = 1  # o dia atual do jogo (começa no DIA 1)

# --- Luz (ver atualizar_luz_do_dia) ---
var momento_da_luz: float = 0.0          # 0.0 a 1.0, o que o gradiente entende
var transicao_do_anoitecer: float = 0.0  # 0 = ainda claro, 1 = noite fechada

# --- Pensamentos do personagem (ver atualizar_pensamentos) ---
var pensamentos_ja_ditos: Array[int] = []  # índices já mostrados neste dia
var tempo_do_proximo_pensamento: float = 0.0  # contagem da insistência noturna

# --- Dormir ---
var dormindo: bool = false  # trava: 2 toques no E não podem dormir 2 vezes

# --- Modo de construção ---
var construcao_ativa: String = ""  # "" = nenhum modo ativo
var fantasma: Node2D = null        # prévia semi-transparente da construção

# --- Conversa com NPC ---
var dialogo_ativo: bool = false   # trava: só uma conversa por vez
var _frame_do_dialogo: int = -1   # ver _atualizar_dialogo (guarda o E do mesmo frame)

func _ready() -> void:
	# O timer conta SÓ o dia. A noite não tem relógio: ela acaba quando o
	# jogador dorme (ver _comecar_a_noite).
	timer.timeout.connect(_comecar_a_noite)
	timer.start()

	if jogador == null:
		push_error("Main: não achei o Player no grupo 'jogador'!")

	hud.construcao_solicitada.connect(_on_construcao_solicitada)

	# Dormir: o Player só AVISA que apertaram E na casa; quem executa é o Main,
	# que é o dono do ciclo dia/noite (call down, signal up).
	if jogador:
		jogador.dormir_solicitado.connect(dormir)

		# Falar com NPC: mesma ideia. O Player diz COM QUEM; a fala do dia
		# (que depende do dia_atual, que só o Main conhece) sai daqui.
		jogador.conversa_solicitada.connect(_on_conversa_solicitada)

	# Clique num slot do inventário = usar o item (comer)
	hud.slot_usado.connect(_on_slot_usado)

	# --- Taxas de desgaste ---
	# Um "dia" do jogo agora é SÓ a fase clara (o wait_time do timer): a
	# noite não tem duração, ela acaba quando o jogador dorme. Daí saem as
	# taxas POR SEGUNDO que o Status aplica a cada frame.
	Status.definir_taxas_de_desgaste(
		_por_segundo(FOME_POR_DIA),
		_por_segundo(SANIDADE_POR_DIA_SEM_COMIDA)
	)

func _process(delta: float) -> void:
	atualizar_luz_do_dia(delta)
	atualizar_pensamentos(delta)

	# --- Conversa com um NPC: durante ela o E é da fala, não do mundo ---
	if dialogo_ativo:
		_atualizar_dialogo()
		return  # e nada de fantasma de construção ao mesmo tempo

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
# USO DE ITENS (clique no slot do inventário)
# =====================================================================
func _on_slot_usado(slot_index: int) -> void:
	if jogador == null:
		return

	var nome: String = jogador.inventario[slot_index]
	if nome == "":
		return  # slot vazio: clicar nele não faz nada

	if jogador.usar_item(slot_index):
		return  # deu certo: a barra sobe e o slot esvazia sozinhos

	hud.mostrar_aviso("Não dá pra usar " + nome + " ainda")

# =====================================================================
# CONSTRUÇÃO
# =====================================================================
func _on_construcao_solicitada(tipo: String) -> void:
	if not RECEITAS.has(tipo):
		push_error("Main: receita desconhecida: " + tipo)
		return

	# Conversando não se constrói: o E está ocupado com a fala
	if dialogo_ativo:
		return

	_cancelar_construcao()  # se já havia um fantasma, descarta ele

	var receita: Dictionary = RECEITAS[tipo]
	if not jogador.tem_itens(receita["custo"]):
		hud.mostrar_aviso("Faltam materiais para " + receita["nome"] + "!")
		return

	var cena: PackedScene = receita["cena"]
	fantasma = cena.instantiate()
	fantasma.modulate.a = 0.5  # semi-transparente = "ainda não construído"
	# Fantasma: camada 0 = não bloqueia o jogador E não é interagível
	_definir_colisao(fantasma, 0)

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
	_definir_colisao(fantasma, 1)
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

# Liga/desliga a colisão de um nó E dos filhos que também colidem (ex: a
# "AreaDormir" do Abrigo). camada 0 = invisível pra física e pro jogador.
func _definir_colisao(no: Node, camada: int) -> void:
	if no is CollisionObject2D:
		no.collision_layer = camada
	for filho in no.get_children():
		if filho is CollisionObject2D:
			filho.collision_layer = camada

# =====================================================================
# CONVERSA COM NPC
# =====================================================================
# O Player só AVISA que apertaram E perto de um NPC. Quem escolhe a fala
# (de acordo com o dia) e manda a HUD desenhar é a Main, porque só ela
# conhece o dia_atual. As falas ficam em scripts/Dialogos.gd.
func _on_conversa_solicitada(npc: NPC) -> void:
	if npc == null or dialogo_ativo or dormindo:
		return

	# O Dialogos já resolve o caso "esse dia ainda não foi escrito":
	# ele repete a última fala escrita, então nunca fica sem nada pra dizer.
	var paginas: Array = Dialogos.falas(npc.chave, dia_atual)
	if paginas.is_empty():
		hud.mostrar_aviso(npc.nome_mostrado + " não tem nada a dizer.")
		return

	dialogo_ativo = true
	if jogador:
		jogador.conversando = true   # o jogador fica parado e o E vira "avançar"

	# O retrato é o próprio quadro do sheet do NPC (esticado pela HUD)
	hud.abrir_dialogo(npc.nome_mostrado, paginas, npc.retrato())

	# O MESMO toque de E que abriu a conversa também chega aqui como
	# "acabou de apertar". Guardamos o frame pra ignorá-lo (senão a
	# primeira fala já apareceria pulada).
	_frame_do_dialogo = Engine.get_process_frames()

func _atualizar_dialogo() -> void:
	# Se a caixa sumiu por fora (não deveria acontecer), solta o jogador
	if not hud.dialogo_aberto():
		_fechar_dialogo()
		return

	if Engine.get_process_frames() == _frame_do_dialogo:
		return  # é o E que abriu a conversa, não um pedido de avançar

	if Input.is_action_just_pressed("ui_cancel"):
		_fechar_dialogo()  # Esc: sai da conversa na hora
	elif Input.is_action_just_pressed("interagir"):
		# avancar_dialogo devolve false quando era a última página
		if not hud.avancar_dialogo():
			_fechar_dialogo()

func _fechar_dialogo() -> void:
	dialogo_ativo = false
	hud.fechar_dialogo()

	# Espera o próximo frame de física pra devolver o E ao jogador, senão o
	# MESMO toque que passou a última fala já reabriria a conversa (é o que
	# a construção faz com o modo_construcao).
	await get_tree().physics_frame
	if jogador:
		jogador.conversando = false

# =====================================================================
# LUZ DO DIA (amanhecer / anoitecer procedural)
# =====================================================================
func atualizar_luz_do_dia(delta: float) -> void:
	if e_noite:
		# A noite NÃO anda sozinha: o céu só termina de escurecer e fica
		# ali, parado, esperando o jogador dormir. A rampa de 4s existe pra
		# entrada da noite não ser um piscar de olhos.
		transicao_do_anoitecer = minf(transicao_do_anoitecer + delta / DURACAO_DO_ANOITECER, 1.0)
		momento_da_luz = lerpf(PONTO_ANOITECER, PONTO_NOITE, transicao_do_anoitecer)
	else:
		# De dia a luz caminha sozinha: 0.0 (amanhecer) até 0.5 (anoitecer)
		momento_da_luz = _andado_do_dia() * PONTO_ANOITECER

	modulacao.definir_momento_do_dia(momento_da_luz)

# =====================================================================
# TEMPO
# =====================================================================
# Quanto do DIA já passou, de 0.0 a 1.0 (time_left conta pra trás).
func _andado_do_dia() -> float:
	if timer.wait_time <= 0.0:
		return 0.0
	return clampf((timer.wait_time - timer.time_left) / timer.wait_time, 0.0, 1.0)

# Transforma "X por dia" em "X por segundo" (um dia = a fase clara do timer).
# É daqui que saem as taxas que o Status aplica frame a frame.
func _por_segundo(valor_por_dia: float) -> float:
	if timer.wait_time <= 0.0:
		return 0.0
	return valor_por_dia / timer.wait_time

# =====================================================================
# CICLO DIA / NOITE (a noite é um PRAZO: ela não passa sozinha)
# =====================================================================
func _comecar_a_noite() -> void:
	e_noite = true

	# O timer PARA aqui. Não existe "depois da noite": quem traz o dia
	# seguinte é o dormir(). É isso que transforma a noite num prazo.
	timer.stop()

	# O céu escurece devagar (quem faz a rampa é o atualizar_luz_do_dia)
	transicao_do_anoitecer = 0.0

	# E a sanidade começa a escorrer: é o relógio da noite agora
	Status.definir_taxa_sanidade_noturna(_por_segundo(SANIDADE_POR_DIA_NA_NOITE))

	# O personagem avisa, e vai repetir a cada INTERVALO_PENSAMENTO_NOITE
	tempo_do_proximo_pensamento = INTERVALO_PENSAMENTO_NOITE
	hud.mostrar_pensamento("Está anoitecendo, preciso dormir.")

# =====================================================================
# PENSAMENTOS DO PERSONAGEM
# =====================================================================
func atualizar_pensamentos(delta: float) -> void:
	if e_noite:
		# De noite ele insiste, até o jogador dormir
		tempo_do_proximo_pensamento -= delta
		if tempo_do_proximo_pensamento <= 0.0:
			tempo_do_proximo_pensamento = INTERVALO_PENSAMENTO_NOITE
			hud.mostrar_pensamento("Está escuro... eu preciso dormir.")
		return

	# De dia cada pensamento sai quando o dia chega na porcentagem dele.
	# Se dois vencerem no mesmo frame, o último é o que fica na tela — mas
	# todos são marcados como ditos, então nenhum deles se repete.
	var andado_do_dia: float = _andado_do_dia()
	for i in PENSAMENTOS_DO_DIA.size():
		if i in pensamentos_ja_ditos:
			continue
		var momento_do_pensamento: float = PENSAMENTOS_DO_DIA[i]["momento"]
		if andado_do_dia >= momento_do_pensamento:
			pensamentos_ja_ditos.append(i)
			hud.mostrar_pensamento(PENSAMENTOS_DO_DIA[i]["texto"])

# =====================================================================
# DORMIR (a vinheta + o sono)
# =====================================================================
func dormir() -> void:
	# Dois toques no E durante a vinheta não podem dormir duas vezes
	if dormindo:
		return

	# Só dá pra dormir de noite
	if not e_noite:
		hud.mostrar_aviso("Você só pode dormir à noite!")
		return

	dormindo = true

	# 1) A pálpebra fecha: a tela escurece por uma vinheta
	await vinheta.fechar()

	# 2) O sono acontece no escuro: o jogador não vê o corte do amanhecer
	e_noite = false
	transicao_do_anoitecer = 0.0   # momento_da_luz = 0.0 = amanhecer
	timer.stop()
	timer.start()                  # começa um dia novo

	dia_atual += 1
	hud.atualizar_contador_dias(dia_atual)

	# A noite acabou: a sanidade para de escorrer
	Status.definir_taxa_sanidade_noturna(0.0)

	# Acorda descansado: sanidade cheia
	# (mudar_sanidade SOMA e faz clamp, então passar o máximo devolve tudo)
	Status.mudar_sanidade(Status.sanidade_maximo)

	# ...mas dormir também gasta energia: custa um pedaço da fome
	Status.mudar_fome(-FOME_PERDIDA_AO_DORMIR)

	# Os pensamentos do dia podem voltar a acontecer amanhã
	pensamentos_ja_ditos.clear()
	tempo_do_proximo_pensamento = 0.0

	# 3) E a pálpebra abre (a vinheta inversa, do centro pra fora)
	await vinheta.abrir()
	dormindo = false
	hud.mostrar_pensamento("Bom dia... o que será que me espera hoje?")
