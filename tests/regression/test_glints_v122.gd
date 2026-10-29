extends SceneTree
const FX=preload('res://scripts/ui/items/item_glints.gd')
const C=preload('res://scripts/data/catalog.gd')
var checks=0
var failures=0
func ck(ok,label):
	checks+=1
	if not ok:failures+=1;printerr('FAIL ',label)
func _initialize():
	for tier in [4,5]:
		var chosen=''
		for kind in FX.anchors:
			if int(C.items[kind].get('craft_tier',C.items[kind].get('rarity',1)))==tier:chosen=kind;break
		ck(not chosen.is_empty(),'tier representative')
		var entry=FX.anchors[chosen];var size=Vector2(entry.size[0],entry.size[1]);var total=0;var tails=0
		for n in 30:
			var at=n*.1;var parts=FX.particles(chosen,size,at);total+=parts.size()
			ck(parts.size()<=(7 if tier==4 else 11),'bounded richer particle budget')
			ck(parts==FX.particles(chosen,size,at),'paused replay is deterministic')
			for part in parts:
				if not part.get('trail',PackedVector2Array()).is_empty():tails+=1
				ck(part.position.distance_to(part.anchor)<maxf(size.x,size.y)*.06,'source edge drift stays attached')
		ck(total/30.0>=(4 if tier==4 else 6),'high quality stays visibly richer tier '+str(tier))
		ck(tails>15,'short luminous trails accompany edge sparks')
	ck(FX.particles('w_sword',Vector2(512,128),1).is_empty(),'low quality retains quiet silhouette')
	print('GLINTS_V122 ',checks,' checks, ',failures,' failures');quit(0 if failures==0 else 1)
