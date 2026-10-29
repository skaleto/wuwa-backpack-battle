extends SceneTree
func _initialize():
 var c=preload('res://scripts/data/catalog.gd');var a=preload('res://scripts/party/crew_abilities_v115.gd')
 var data={'version':c.SIMULATION_VERSION,'leaders':c.selectable_leaders().map(func(k):return {'id':k,'name':c.characters[k].name,'weapon':c.characters[k].weapon_type,'starter':c.items[c.characters[k].starter].name,'opening':c.characters[k].passive}),'companions':a.profiles(),'full_team':a.BONDS}
 FileAccess.open('res://build/qa/recruitment-v115/rules.json',FileAccess.WRITE).store_string(JSON.stringify(data,'\t'))
 quit()
