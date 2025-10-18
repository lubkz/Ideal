# res://Data/HabilidadeData.gd
class_name HabilidadeData extends Resource

@export var nome: String = ""
@export var dano_base: int = 10
@export var custo_recarca: int = 0 # Turnos de recarga
@export var efeito_status: String = "" # "Cegueira", "Atordoamento", "Nenhum"
@export var tipo: String = "" # "Físico", "Contenção", "Sádico", "Caótico"
@export var descricao: String = "" # Para tooltip no UI
