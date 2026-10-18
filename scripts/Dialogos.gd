class_name Dialogos
extends RefCounted

# =====================================================================
# DIÁLOGOS DOS NPCs — fonte única de verdade (igual ao CatalogoItens.gd)
#
# COMO ESCREVER:
#   * Cada NPC é uma chave: "crianca", "pai", "rosa".
#   * Dentro dela, cada DIA é uma chave numérica: 1, 2, 3...
#   * O valor de cada dia é uma LISTA DE FALAS (páginas). Cada página
#     aparece sozinha na caixa de diálogo e o jogador aperta E pra passar
#     pra próxima. Um dia com 1 página = uma lista de 1 item.
#
# Exemplo:
#     "rosa": {
#         1: ["Oi!", "Você é novo por aqui, né?"],
#     },
#
# REGRAS:
#   * Um diálogo por dia: no dia 3, o NPC fala o bloco do dia 3.
#   * Se o jogador chegar num dia que ainda não foi escrito (você está
#     escrevendo o jogo, isso vai acontecer direto), o NPC REPETE a última
#     fala escrita — o jogo nunca fica mudo nem quebra.
#   * Trocar de dia durante a conversa não corta a fala: as páginas são
#     lidas de uma vez quando a conversa começa.
#
# OS TEXTOS ABAIXO SÃO PROVISÓRIOS. Pode sobrescrever tudo — o sistema
# não depende do conteúdo, só da forma (chave -> dia -> lista de páginas).
# =====================================================================
const FALAS: Dictionary = {
	"pai": {
		1: [
			"Você acordou... Achei que não fosse aguentar a noite.",
			"A ilha não é gentil depois que o sol cai. Durma sempre que anoitecer.",
		],
		2: [
			"Já achou madeira suficiente? Com duas e uma pedra eu te ajudo a levantar um abrigo.",
		],
		3: [
			"Todo mundo aqui chegou de barco. Nenhum voltou pelo mesmo caminho.",
		],
	},
	"crianca": {
		1: [
			"Oi! Você é grande igual meu pai!",
			"Ele disse que você veio do mar. É verdade?",
		],
		2: [
			"Eu vi uma ovelha pulando perto do mato. Ela faz assim, ó!",
		],
		3: [
			"Meu pai fica sério quando fala do barco. Acho que é coisa de gente grande.",
		],
	},
	"rosa": {
		1: [
			"Calma, respira. Você chegou com vida, isso já é sorte.",
			"Se precisar comer, guarda a carne no inventário. Fome aqui não perdoa.",
		],
		2: [
			"À noite eu não saio de perto de casa. Você também não deveria.",
		],
		3: [
			"O barco tá lá no canto da praia. Um dia a gente conserta ele, se você sobreviver o bastante.",
		],
	},
}


## As páginas da conversa do dia. Devolve uma lista de Strings (pode ser
## uma lista vazia se a chave não existir).
static func falas(chave: String, dia: int) -> Array:
	if not FALAS.has(chave):
		push_warning("Dialogos: nenhum NPC cadastrado com a chave '%s'." % chave)
		return []

	var por_dia: Dictionary = FALAS[chave]
	if por_dia.is_empty():
		return []

	if por_dia.has(dia):
		return por_dia[dia]

	# Dia além do que já foi escrito: repete a ÚLTIMA fala escrita.
	# (é o que deixa o jogo jogável enquanto os textos estão sendo feitos)
	var ultimo_dia: int = 0
	for d in por_dia.keys():
		if int(d) <= dia and int(d) > ultimo_dia:
			ultimo_dia = int(d)

	if ultimo_dia == 0:
		# Todos os dias escritos são futuros: usa o menor deles
		for d in por_dia.keys():
			if ultimo_dia == 0 or int(d) < ultimo_dia:
				ultimo_dia = int(d)

	return por_dia[ultimo_dia]


## Todos os dias já escritos pra um NPC (útil pra debug/validação)
static func dias_escritos(chave: String) -> Array:
	if not FALAS.has(chave):
		return []
	var dias: Array = FALAS[chave].keys()
	dias.sort()
	return dias
