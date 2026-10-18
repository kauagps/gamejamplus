extends Node2D

# Distância (em pixels) que a prévia fica à frente do jogador
const DISTANCIA_CONSTRUCAO: float = 32.0

# --- LARGAR ITEM (Q) ---
# A que distância (em pixels) o item largado cai à frente do John
const DISTANCIA_LARGAMENTO: float = 32.0

# O item largado é o MESMO Item.tscn dos itens do mapa: ele já nasce no grupo
# "item" (o E pega de volta), na camada de física certa e com a colisão
# calibrada. Não existe "item largado" como coisa nova.
const CENA_ITEM_NO_CHAO: PackedScene = preload("res://cenas/Item.tscn")

# O recado do modo largar fica numa constante porque o Main REPETE a mesma
# frase de tempo em tempo: o aviso dourado some sozinho em 2s, mas o modo
# continua armado (e um clique no slot largaria o item em vez de comer).
const RECADO_LARGAR: String = "Clique no item que quer largar (Esc desiste)"
const INTERVALO_RECADO_LARGAR: float = 1.8

# O mesmo esquema, agora pro modo de construção: a HUD mostra o recado, ele
# some em 2s e o Main renova enquanto o fantasma estiver na mão do jogador.
# Sem isso o jogador clica no botão, aparece a prévia... e ninguém diz que o
# E constrói. O recado também é escondido na hora quando o modo acaba
# (hud.esconder_aviso), senão ele fica 2s na tela dizendo o contrário.
const RECADO_CONSTRUIR: String = "E constrói · Esc desiste"
const INTERVALO_RECADO_CONSTRUIR: float = 1.8

# --- FOME ---
# Quanto da barra de fome o jogador perde por dia (em pontos).
# 100 = a barra inteira em um dia, que foi o que você escolheu.
# Como a conta abaixo usa a duração REAL do dia (TimerDiaNoite), mudar o
# wait_time do timer no Inspector já ajusta a velocidade da fome sozinho.
const FOME_POR_DIA: float = 100.0

# Quanto de sanidade cai por dia quando a fome está zerada
const SANIDADE_POR_DIA_SEM_COMIDA: float = 50.0

# --- SANIDADE x FOME (o eixo da mecânica de sanidade) ---
# A sanidade não é só uma barra que escorre de noite: ela anda junto com a
# barriga. Note que o LIMITE (60% de fome) mora no Status.gd, junto das
# regras dos medidores — aqui ficam só as quantidades por dia.
const SANIDADE_POR_DIA_COMENDO_BEM: float = 50.0   # fome acima de 60%
const SANIDADE_POR_DIA_FOME_BAIXA: float = 25.0    # fome entre 1 e 60%

# Quanto dormir devolve de sanidade. NÃO é mais a barra cheia: dormir
# alivia, mas quem mantém a cabeça sã é COMER.
const SANIDADE_GANHA_AO_DORMIR: float = 40.0

# --- EFEITO DA SANIDADE NA TELA ---
# Abaixo desta fração da barra a tela começa a "adoecer": as bordas fecham,
# a imagem ondula e a câmera trema — e tudo piora até o game over.
# 0.6 é o MESMO 60% da fome, de propósito: a tela começa a escurecer
# exatamente quando a cabeça para de se recuperar sozinha.
const LIMITE_SANIDADE_TELA: float = 0.6

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

# --- ABERTURA (o despertar do dia 1) ---
# O jogo NÃO começa com o mundo ligado: ele nasce com a pálpebra fechada e
# ela abre bem devagar (a do dormir é 1s; esta é bem mais lenta), como quem
# abre os olhos depois de uma queda. Só depois disso o mundo começa a correr.
const ABERTURA_DURACAO_DOS_OLHOS: float = 4.0

# O tutorial mais barato que existe: sem caixa de instrução, sem seta
# apontando. A própria "voz" do John, desnorteada, ensina o que fazer.
# Ele pensa uma por vez, na ordem desta lista.
const ABERTURA_PENSAMENTOS: Array[String] = [
	"Onde... onde eu estou?",
	"Estou com fome... e com frio.",
	"Preciso sobreviver.",
	"Tem gravetos e frutas ali. É melhor eu pegar.",
]

# Quanto cada pensamento da abertura fica na tela, e o respiro entre eles
# (é um tempo menor que o normal: aqui são várias frases em fila)
const ABERTURA_DURACAO_PENSAMENTO: float = 2.6
const ABERTURA_PAUSA: float = 0.4

# --- HISTÓRIA DA MADRUGADA (o cartão no meio da tela) ---
# A chave é o DIA QUE ACABOU DE TERMINAR: a noite do dia 1 é a chave 1.
# O texto aparece por cima da vinheta (tela já preta) e SÓ SAI quando o
# jogador aperta E. Noite sem chave aqui = noite sem cartão, que é o normal.
const HISTORIA_DA_MADRUGADA: Dictionary = {
	1: "Durante a madrugada, você roubou um pedaço de carne da família de sobreviventes.",
}

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
@onready var cartao: CartaoHistoria = $CartaoHistoria
@onready var cutscene: Cutscene = $Cutscene
@onready var node_construcoes: Node2D = $Node  # nó com y_sort_enabled
@onready var jogador: Node2D = get_tree().get_first_node_in_group("jogador")

# O efeito da sanidade na tela (bordas, ondulação e tremor) e a tela final.
# Os dois são irmãos dela na Main.tscn, como a vinheta e o cartão.
@onready var tela_doente: SanidadeVisual = $SanidadeVisual
@onready var tela_final: GameOver = $GameOver

# O som do mundo: ambiências (vento/insetos), o crossfade da noite e o
# pacote do pânico. A Main manda, ele obedece (ver Audio.gd).
@onready var audio: Audio = $Audio

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

# --- Modo largar (Q) ---
# O Q não adivinha qual item sai da mochila: ele ARMA um modo, e o jogador
# aponta o slot com o MESMO clique que já existia (o do "comer"). Assim não
# nasce um segundo jeito de mexer no inventário, e não tem como largar o item
# errado por acidente. Esc desiste.
var largando: bool = false
var tempo_do_recado_de_largar: float = 0.0  # ver _process

# Mesmo par do largar, agora pro modo de construção (ver RECADO_CONSTRUIR):
# é o tempo que falta pra repetir o "E constrói · Esc desiste" na tela.
var tempo_do_recado_de_construcao: float = 0.0  # ver _process

# --- Conversa com NPC ---
var dialogo_ativo: bool = false   # trava: só uma conversa por vez
var _frame_do_dialogo: int = -1   # ver _atualizar_dialogo (guarda o E do mesmo frame)

# --- Fim de jogo (a sanidade zerou) ---
# Vira true no game over. Serve pra duas coisas: o game over não dispara
# duas vezes, e o efeito de sanidade na tela se desliga (a vinheta já está
# fechando — a câmera não precisa tremer no escuro).
var acabou_o_jogo: bool = false

func _ready() -> void:
	# O timer conta SÓ o dia. A noite não tem relógio: ela acaba quando o
	# jogador dorme (ver _comecar_a_noite).
	# IMPORTANTE: ele não começa aqui embaixo. Quem dá a partida no relógio é
	# a abertura, no fim do arquivo — senão o tutorial "desnorteado" comeria
	# um pedaço do dia 1 com o John ainda parado, de olhos fechados.
	timer.timeout.connect(_comecar_a_noite)

	if jogador == null:
		push_error("Main: não achei o Player no grupo 'jogador'!")

	hud.construcao_solicitada.connect(_on_construcao_solicitada)

	# O PREÇO de cada construção mora no RECEITAS (aqui), mas quem desenha é a
	# HUD. A Main manda pra baixo (call down), uma vez por receita — assim o
	# preço da tela e o do RECEITAS nunca ficam fora de sincronia: mudar o
	# custo aqui já muda o número, os ícones e o tooltip lá.
	# Roda no _ready da Main, ou seja DEPOIS do _ready da HUD (filho primeiro):
	# quando a HUD recebe isto, os botões, os slots e o jogador já existem.
	for tipo in RECEITAS:
		hud.definir_custo_de_construcao(tipo, RECEITAS[tipo]["nome"], RECEITAS[tipo]["custo"])

	# Dormir: o Player só AVISA que apertaram E na casa; quem executa é o Main,
	# que é o dono do ciclo dia/noite (call down, signal up).
	if jogador:
		jogador.dormir_solicitado.connect(dormir)

		# Falar com NPC: mesma ideia. O Player diz COM QUEM; a fala do dia
		# (que depende do dia_atual, que só o Main conhece) sai daqui.
		jogador.conversa_solicitada.connect(_on_conversa_solicitada)

		# Entregar material ao barco: o Player diz que o jogador quer; quem
		# desconta o inventário e alimenta o Barco é a Main (dona do fluxo).
		jogador.barco_solicitado.connect(_on_barco_solicitado)

	# Clique num slot do inventário = usar o item (comer)
	hud.slot_usado.connect(_on_slot_usado)

	# Fim de jogo: quem avisa é o Status (a barra encostou no zero); quem
	# decide o que fazer com isso é a Main (call down, signal up).
	Status.sanidade_zerada.connect(game_over)

	# --- As taxas do mundo ---
	# Um "dia" do jogo é SÓ a fase clara (o wait_time do timer): a noite não
	# tem duração, ela acaba quando o jogador dorme. Daí saem as taxas POR
	# SEGUNDO que o Status aplica a cada frame (ver _ligar_o_mundo).
	_ligar_o_mundo()

	# Os passos do John são de GRAMA, e hoje ele anda por cima da água (a
	# água não tem colisão — bug conhecido e aceito). Quem é dono do mapa é a
	# Main, então é ela que aponta a camada de tiles do chão; o Player só
	# pergunta a ela se está em chão firme antes de acender os passos.
	if jogador:
		jogador.camada_do_chao = $Terra

	# --- CUTSCENE DO PRÓLOGO: o avião caindo ---
	# Antes de qualquer coisa: o mundo nasce de olhos fechados E parado, e é
	# a cutscene que aparece por cima do preto (ela vive na camada 105, acima
	# da vinheta). O som do mundo nasce calado — durante o prólogo quem manda
	# no ouvido é o avião.
	#
	# Três coisas ficam travadas aqui: a pálpebra já fechada (senão o mundo
	# apareceria por um frame antes da cena), o John (em_cena) e o relógio da
	# fome/sanidade (_parar_o_mundo), que voltam na abertura logo abaixo.
	audio.calar()
	vinheta.fechar_de_uma_vez()
	if jogador:
		jogador.em_cena = true
	_parar_o_mundo()

	await cutscene.mostrar()

	# --- Aí sim o som do mundo acorda ---
	# O vento entra junto com a pálpebra (o nó do áudio nasce em silêncio e
	# sobe sozinho — ver Audio.gd) e os EFEITOS nascem mudos, porque a
	# abertura é uma CENA: o John ainda não anda e não é hora de ouvir ovelha.
	audio.ir_para_o_dia()
	audio.definir_efeitos_ligados(false)

	# --- Abertura: o despertar do dia 1 ---
	_iniciar_a_abertura()


# =====================================================================
# ABERTURA (o despertar do dia 1)
# =====================================================================
# O jogo nasce com os olhos fechados, abre devagar, e o John começa a
# pensar desnorteado. É a cena de abertura E o tutorial, na mesma coisa.
func _iniciar_a_abertura() -> void:
	# 1) Nasce com a tela preta (sem animação: ninguém "vê" o preto nascer)
	vinheta.fechar_de_uma_vez()

	# 2) E o jogador também ainda "não acordou": não anda, o E não interage
	if jogador:
		jogador.em_cena = true

	# 3) O mundo também espera. Ele acordou agora: ninguém perde fome
	#    enquanto ouve a própria cabeça. (As taxas voltam no fim da cena.)
	_parar_o_mundo()

	# 4) Uns instantes de preto, e a pálpebra abre BEM devagar
	await get_tree().create_timer(0.6).timeout
	await vinheta.abrir(ABERTURA_DURACAO_DOS_OLHOS)

	# 5) Um respiro de olhos abertos antes da primeira ideia
	await get_tree().create_timer(0.4).timeout

	# 6) Desnorteado, ele pensa uma frase por vez: é o tutorial
	for pensamento in ABERTURA_PENSAMENTOS:
		hud.mostrar_pensamento(pensamento, ABERTURA_DURACAO_PENSAMENTO)
		await get_tree().create_timer(ABERTURA_DURACAO_PENSAMENTO + ABERTURA_PAUSA).timeout

	# 7) Acabou o tutorial: o mundo liga de verdade
	if jogador:
		jogador.em_cena = false

	_ligar_o_mundo()

	# E os efeitos do mundo também ligam: agora sim o John anda (passos) e as
	# ovelhas podem berrar sem entregar que o mundo rodava no escuro.
	audio.definir_efeitos_ligados(true)

	# E o relógio do dia 1 começa a andar só agora
	timer.start()


func _process(delta: float) -> void:
	atualizar_luz_do_dia(delta)
	atualizar_pensamentos(delta)
	_atualizar_painel_do_barco()
	_atualizar_sanidade()

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
		else:
			# Mesmo esquema do modo largar logo abaixo: o aviso dourado some
			# sozinho em 2s, mas o modo segue armado — então o recado se
			# renova enquanto o fantasma estiver na mão do jogador.
			tempo_do_recado_de_construcao -= delta
			if tempo_do_recado_de_construcao <= 0.0:
				tempo_do_recado_de_construcao = INTERVALO_RECADO_CONSTRUIR
				hud.mostrar_aviso(RECADO_CONSTRUIR)

	# --- Modo largar (Q): o Q arma; quem escolhe o item é o clique no slot ---
	if Input.is_action_just_pressed("dropar") and _pode_usar_o_q():
		_alternar_modo_largar()
	elif largando:
		if Input.is_action_just_pressed("ui_cancel"):
			_sair_do_modo_largar()
		else:
			# O aviso dourado some sozinho em 2s, mas o modo segue armado —
			# e aí o clique no slot largaria em vez de comer SEM o jogador
			# saber. Por isso o recado se renova enquanto o modo durar.
			tempo_do_recado_de_largar -= delta
			if tempo_do_recado_de_largar <= 0.0:
				tempo_do_recado_de_largar = INTERVALO_RECADO_LARGAR
				hud.mostrar_aviso(RECADO_LARGAR)

# =====================================================================
# USO DE ITENS (clique no slot do inventário)
# =====================================================================
func _on_slot_usado(slot_index: int) -> void:
	if jogador == null:
		return

	# Modo largar armado: este clique não come, ele joga fora
	if largando:
		_largar_item_do_slot(slot_index)
		return

	var nome: String = jogador.inventario[slot_index]
	if nome == "":
		return  # slot vazio: clicar nele não faz nada

	if jogador.usar_item(slot_index):
		return  # deu certo: a barra sobe e o slot esvazia sozinhos

	hud.mostrar_aviso("Não dá pra usar " + nome + " ainda")

# =====================================================================
# LARGAR ITEM NO CHÃO (Q → clique no slot)
# =====================================================================
# Q só vale com o mundo "solto": nada de largar item conversando, dormindo,
# dentro da abertura (em_cena) ou no meio de uma construção.
func _pode_usar_o_q() -> bool:
	if jogador == null or dormindo or dialogo_ativo or fantasma != null:
		return false
	return not jogador.em_cena

func _alternar_modo_largar() -> void:
	largando = not largando
	hud.destacar_slots_para_largar(largando)

	if largando:
		tempo_do_recado_de_largar = INTERVALO_RECADO_LARGAR
		hud.mostrar_aviso(RECADO_LARGAR)
	else:
		hud.mostrar_aviso("Deixa quieto então")

# "avisar" existe pro caso de outro modo (a construção) desarmar o largar:
# aí o jogador não pediu pra desistir, então não precisa de recado.
func _sair_do_modo_largar(avisar: bool = true) -> void:
	if not largando:
		return

	largando = false
	hud.destacar_slots_para_largar(false)
	if avisar:
		hud.mostrar_aviso("Nada foi largado")

func _largar_item_do_slot(slot_index: int) -> void:
	# Largou: o modo cumpriu o papel dele (e a HUD volta ao normal)
	largando = false
	hud.destacar_slots_para_largar(false)

	# Quem manda no inventário é o Player: aqui só PEDIMOS o item de volta
	var nome: String = jogador.tirar_item(slot_index)
	if nome == "":
		hud.mostrar_aviso("Esse slot está vazio")
		return

	_soltar_item_no_chao(nome, _lugar_do_largamento())
	hud.mostrar_aviso("Largou " + nome)

# Cria o item no mundo, no nó com y_sort das construções — assim ele acerta
# a profundidade sozinho (atrás da árvore, na frente da grama...).
func _soltar_item_no_chao(nome: String, posicao: Vector2) -> void:
	var item: Item = CENA_ITEM_NO_CHAO.instantiate()
	item.nome_do_item = nome  # antes do add_child: o _ready lê daqui
	node_construcoes.add_child(item)
	item.global_position = posicao

	# Exceção da fruta: no chão ela é um arbusto, mas largada é uma frutinha
	# (quem diz isso é o "solto" do catálogo; item sem "solto" não entra aqui).
	var solto: Dictionary = CatalogoItens.solto(nome)
	if solto.has("sprite"):
		item.sprite.texture = solto["sprite"]
		item.sprite.scale = Vector2.ONE * float(solto.get("zoom_sprite", 1.0))

# Onde o item cai: um passo à frente do John. Se ali tiver parede/árvore, ele
# cai nos pés — melhor um item no pé do que um item preso dentro de um sólido,
# onde o jogador nunca conseguiria alcançar de novo.
func _lugar_do_largamento() -> Vector2:
	var na_frente: Vector2 = jogador.global_position + jogador.ultima_direcao * DISTANCIA_LARGAMENTO
	if _espaco_livre(na_frente):
		return na_frente
	return jogador.global_position

# Tem algo SÓLIDO (camada 1: árvore, parede, construção) encostando aqui?
func _espaco_livre(posicao: Vector2) -> bool:
	var consulta := PhysicsShapeQueryParameters2D.new()
	var forma := CircleShape2D.new()
	forma.radius = 8.0
	consulta.shape = forma
	consulta.transform = Transform2D(0.0, posicao)
	consulta.collision_mask = 1
	return get_world_2d().direct_space_state.intersect_shape(consulta, 1).is_empty()

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

	# Construção e largar disputam o clique do mouse: entrar num desarma o outro
	_sair_do_modo_largar(false)

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

	# Ensina o que fazer com a prévia que acabou de aparecer. Antes o jogador
	# clicava e ficava com um quadrado translúcido na frente sem instrução
	# nenhuma. Daqui pra frente o recado se renova sozinho (ver _process).
	hud.mostrar_aviso(RECADO_CONSTRUIR)
	tempo_do_recado_de_construcao = INTERVALO_RECADO_CONSTRUIR


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

	# Fecha o recado do modo com um "pronto" — o aviso dourado é o MESMO
	# label, então isto substitui o "E constrói" (que não vale mais) e
	# confirma que a construção saiu.
	hud.mostrar_aviso("Construção pronta: " + receita["nome"])

	# Espera o próximo frame de física pra liberar o E, senão o MESMO toque
	# que confirmou a construção também pegaria um item no mesmo frame
	await get_tree().physics_frame
	jogador.modo_construcao = false


func _cancelar_construcao() -> void:
	if fantasma:
		fantasma.queue_free()
		fantasma = null
		# Esc: o modo acabou, então o "E constrói · Esc desiste" some NA HORA
		# em vez de ficar 2s na tela dizendo pra apertar uma tecla que não
		# faz mais nada. (Só quando havia fantasma: se ninguém estava
		# construindo, este cancelar não pode apagar um aviso alheio, tipo o
		# "Faltam materiais para Abrigo!" que o _on_construcao_solicitada
		# mostra logo depois.)
		hud.esconder_aviso()
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
# BARCO (objetivo final) — entregar madeira e pedra
# =====================================================================
# O E no barco é igual ao E na casa: o Player só AVISA que o jogador quer
# entregar (signal barco_solicitado). Aqui a Main costura os três donos:
#   - o inventário é do Player  -> retirar_itens_do_tipo()
#   - a obra é do Barco         -> receber()
#   - o painel é da HUD         -> mostrar_painel_do_barco()
func _on_barco_solicitado(barco: Barco) -> void:
	if barco == null or jogador == null:
		return

	if barco.esta_pronto():
		hud.mostrar_aviso("O barco já está consertado")
		return

	# Entrega TUDO o que couber do que o jogador tem, de uma vez: a mochila
	# só tem 3 slots e o barco pede 30 itens, então um por aperto seriam 30
	# apertos. O limite de cada chamada é exatamente o que ainda falta.
	var madeiras: int = jogador.retirar_itens_do_tipo("madeira", barco.falta_madeira())
	var pedras: int = jogador.retirar_itens_do_tipo("pedra", barco.falta_pedra())

	if madeiras == 0 and pedras == 0:
		hud.mostrar_aviso("O barco precisa de madeira e pedra")
		return

	barco.receber(madeiras, pedras)

	var partes: Array[String] = []
	if madeiras > 0:
		partes.append("%d madeira%s" % [madeiras, "" if madeiras == 1 else "s"])
	if pedras > 0:
		partes.append("%d pedra%s" % [pedras, "" if pedras == 1 else "s"])
	hud.mostrar_aviso("Entregou " + " e ".join(partes))


# Painel flutuante em cima do barco: aparece só com o John no alcance dele.
# Roda todo frame porque ele também se reposiciona (o barco não anda, mas a
# CÂMERA sim) e porque o texto muda quando o jogador pega/solta material.
func _atualizar_painel_do_barco() -> void:
	if jogador == null:
		return

	var barco: Barco = jogador.barco_proximo
	if barco == null:
		hud.esconder_painel_do_barco()
		return

	# "Dá pra interagir?" = o John tem alguma madeira ou pedra na mochila
	var tem_material: bool = (
		jogador.quantos_do_tipo("madeira") > 0
		or jogador.quantos_do_tipo("pedra") > 0
	)

	hud.mostrar_painel_do_barco(
		barco.falta_madeira(),
		barco.falta_pedra(),
		tem_material and not barco.esta_pronto(),
		barco.global_position
	)

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
	# Antes de o relógio começar (a abertura do jogo), o dia ainda é 0%.
	# Sem esta linha, o time_left de um timer parado (0) daria 100% e o céu
	# nasceria no ponto do anoitecer.
	if timer.is_stopped():
		return 0.0
	return clampf((timer.wait_time - timer.time_left) / timer.wait_time, 0.0, 1.0)

# Transforma "X por dia" em "X por segundo" (um dia = a fase clara do timer).
# É daqui que saem as taxas que o Status aplica frame a frame.
func _por_segundo(valor_por_dia: float) -> float:
	if timer.wait_time <= 0.0:
		return 0.0
	return valor_por_dia / timer.wait_time


# =====================================================================
# LIGAR / PARAR O MUNDO (todas as taxas do Status num lugar só)
# =====================================================================
# Isto existe por um motivo chato de descobrir do jeito difícil: cada taxa
# nova que nasce no Status precisa ser zerada em TODA cena que pausa o
# mundo (dormir, abertura, game over) — e esquecer uma delas faz ela vazar
# (ex: a sanidade subindo enquanto o jogador lê o cartão da madrugada).
# Com estas duas funções, ligar e desligar o mundo é um lugar só.
func _parar_o_mundo() -> void:
	Status.definir_taxas_de_desgaste(0.0, 0.0)
	Status.definir_taxas_de_sanidade_por_fome(0.0, 0.0)
	Status.definir_taxa_sanidade_noturna(0.0)


func _ligar_o_mundo() -> void:
	Status.definir_taxas_de_desgaste(
		_por_segundo(FOME_POR_DIA),
		_por_segundo(SANIDADE_POR_DIA_SEM_COMIDA)
	)
	Status.definir_taxas_de_sanidade_por_fome(
		_por_segundo(SANIDADE_POR_DIA_COMENDO_BEM),
		_por_segundo(SANIDADE_POR_DIA_FOME_BAIXA)
	)
	# A taxa da NOITE não entra aqui de propósito: ela nasce quando o sol se
	# põe (ver _comecar_a_noite) e morre quando o jogador dorme. De dia ela
	# é zero por natureza.

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

	# E o som troca junto com o céu: o vento sai, os insetos entram. O
	# crossfade do Audio leva os mesmos 4s da rampa da luz — de propósito.
	audio.ir_para_a_noite()

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
# SANIDADE NA TELA E NO SOM (o mundo "adoece" junto com a cabeça)
# =====================================================================
# A conta da severidade mora AQUI (e não nos nós que obedecem) por dois
# motivos:
#   1) só a Main sabe quando o mundo está parado numa cena (dormir, abertura)
#   2) a régua é a mesma da mecânica: os dois efeitos começam em
#      LIMITE_SANIDADE_TELA (60%) e pioram até a sanidade zerar.
# Quem recebe a severidade: a SanidadeVisual (a tela fecha e a câmera treme)
# e o Audio (respiração -> coração -> tempestade — a escadinha do Audio.gd).
# A HUD e o painel do barco ficam de fora: no meio de um surto o jogador
# ainda precisa conseguir ler a própria barra de sanidade.
func _atualizar_sanidade() -> void:
	if jogador == null:
		return

	var severidade: float = 0.0
	if not jogador.em_cena and not acabou_o_jogo:
		var limite: float = Status.sanidade_maximo * LIMITE_SANIDADE_TELA
		if limite > 0.0 and Status.sanidade < limite:
			severidade = clampf(1.0 - Status.sanidade / limite, 0.0, 1.0)

	tela_doente.definir_severidade(severidade)
	audio.definir_panico(severidade)


# =====================================================================
# GAME OVER (a sanidade zerou)
# =====================================================================
# A ordem: o mundo para, o jogador sai do controle, a tela fecha (a MESMA
# vinheta do dormir) e a tela final aparece por cima do preto. Quando o
# jogador aperta E, o jogo recomeça do zero.
#
# O recomeço é um RELOAD da cena: a Main.tscn inteira nasce de novo, com o
# dia 1, a abertura e tudo. A única coisa que sobrevive a isso é o Autoload
# Status — por isso ele é reiniciado na mão antes (ver Status.reiniciar).
#
# Mais pra frente isto vira um ir_para_o_menu(): quando a cena do menu
# existir, é só trocar o reload por um change_scene_to_file pra ela.
func game_over() -> void:
	if acabou_o_jogo:
		return
	acabou_o_jogo = true

	# O mundo para de correr (senão a fome continuaria caindo no escuro)
	_parar_o_mundo()
	timer.stop()

	# E o som do mundo vai junto: a vinheta fecha no silêncio (a tempestade
	# que estava tocando morre aqui, com a cabeça do John).
	audio.calar()

	# E o jogador sai do controle: não anda mais, o E não interage
	if jogador:
		jogador.em_cena = true

	# Escurece como no dormir, e o aviso final aparece sobre o preto
	await vinheta.fechar()
	await tela_final.mostrar()

	# Recomeça do zero (ver o comentário acima sobre o Autoload)
	Status.reiniciar()
	get_tree().reload_current_scene()


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

	# O jogador sai do controle: dormir é uma CENA. Sem isso ele andaria no
	# escuro e o E que fecha o cartão de história também pegaria um item.
	if jogador:
		jogador.em_cena = true

	# O sono também PARA o desgaste do mundo: nada de fome/sanidade caindo
	# enquanto o jogador lê o cartão da madrugada (o gasto do sono continua
	# sendo cobrado explicitamente, em FOME_PERDIDA_AO_DORMIR, logo abaixo).
	_parar_o_mundo()

	# E o mundo fica MUDO: dormir é uma cena. Isto também abaixa os efeitos
	# (passos, berros) — o John não está mais lá fora com os olhos abertos.
	audio.calar()

	# 1) A pálpebra fecha: a tela escurece por uma vinheta
	await vinheta.fechar()

	# 1.5) Com a tela preta, a madrugada pode ser contada (se tiver história).
	#      Isto só termina quando o jogador apertar E.
	await _contar_a_madrugada()

	# 2) O sono acontece no escuro: o jogador não vê o corte do amanhecer
	e_noite = false
	transicao_do_anoitecer = 0.0   # momento_da_luz = 0.0 = amanhecer
	timer.stop()
	timer.start()                  # começa um dia novo

	dia_atual += 1
	hud.atualizar_contador_dias(dia_atual)

	# (a sanidade da noite já parou lá em cima, junto com o desgaste)

	# Acorda com a cabeça melhor — mas NÃO inteira: dormir alivia, quem
	# mantém a cabeça sã é comer (é o eixo da mecânica de sanidade x fome).
	Status.mudar_sanidade(SANIDADE_GANHA_AO_DORMIR)

	# ...mas dormir também gasta energia: custa um pedaço da fome
	Status.mudar_fome(-FOME_PERDIDA_AO_DORMIR)

	# Os pensamentos do dia podem voltar a acontecer amanhã
	pensamentos_ja_ditos.clear()
	tempo_do_proximo_pensamento = 0.0

	# 3) E a pálpebra abre (a vinheta inversa, do centro pra fora)
	await vinheta.abrir()
	dormindo = false
	if jogador:
		jogador.em_cena = false

	# Amanheceu: o dia novo volta a corroer o jogador
	_ligar_o_mundo()

	# E o som volta: manhã nova é vento (e os efeitos do mundo reabrem)
	audio.ir_para_o_dia()

	hud.mostrar_pensamento("Bom dia... o que será que me espera hoje?")


# =====================================================================
# HISTÓRIA DA MADRUGADA
# =====================================================================
# Roda com a tela já escura (dentro da vinheta). Se aquela noite tiver um
# texto no HISTORIA_DA_MADRUGADA, ele aparece no meio da tela e o jogo só
# continua quando o jogador aperta E.
func _contar_a_madrugada() -> void:
	if not HISTORIA_DA_MADRUGADA.has(dia_atual):
		return

	await get_tree().create_timer(0.5).timeout  # um respiro no escuro primeiro
	await cartao.mostrar(HISTORIA_DA_MADRUGADA[dia_atual])
