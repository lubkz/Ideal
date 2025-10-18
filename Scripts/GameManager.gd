extends Node

var current_player_position: Vector2 # Guardar a posição do player antes da batalha
var enemies_to_fight: Array # Array de EnemyData resources
var current_party_members: Array # Array de PartyMemberData resources

func start_battle(enemies: Array, party_members: Array, player_pos: Vector2):
	current_player_position = player_pos
	enemies_to_fight = enemies
	current_party_members = party_members # Ou você pode pegar do seu PartyManager
	
	# Salvar estado do mapa atual se necessário
	# Get_tree().change_scene("res://Scenes/Battles/BattleScene.tscn")
	# Para transições mais suaves, considere add_child() e remover a cena do mapa
	var battle_scene = load("res://Cenas/batle_scene.tscn").instance()
	get_tree().current_scene.add_child(battle_scene) # Adiciona a cena de batalha sobre a cena do mapa
	get_tree().paused = true # Pausa o jogo do mapa enquanto a batalha acontece
	battle_scene.connect("battle_ended", self, "_on_BattleScene_battle_ended")

func _on_BattleScene_battle_ended(won: bool):
	get_tree().paused = false
	# Remover a cena de batalha
	var battle_scene = get_tree().current_scene.find_node("BattleScene", true, false)
	if battle_scene:
		battle_scene.queue_free()
	
	if won:
		# Voltar à posição do jogador
		# Seu player no mapa precisa ser atualizado com current_player_position
		print("Batalha vencida!")
	else:
		print("Game Over ou Fuga!")
		# Tratar Game Over ou retorno para tela inicial
