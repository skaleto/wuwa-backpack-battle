extends SceneTree
const I=preload("res://scripts/inventory/inventory.gd")
var checks=0
var failures=0
func ck(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize()->void:
	var path="res://scripts/ui/pockets/bag_material.gd"
	ck(ResourceLoader.exists(path),"bag material projection exists independently from gameplay")
	if not ResourceLoader.exists(path):quit(1);return
	var material=load(path)
	var inventory=I.new()
	var resources={}
	for kind in ["satchel","pouch","strip","corner","travel"]:
		var profile=material.profile(kind)
		ck(FileAccess.file_exists(profile.path),kind+" has an actual authored material")
		resources[profile.path]=true
		for turns in 4:
			var piece=inventory.make_piece(kind,"qa")
			piece.rotation=turns
			var bounds=Rect2()
			for cell in inventory.cells(piece):
				var r=Rect2(Vector2(cell)*80,Vector2.ONE*80)
				bounds=r if bounds.size==Vector2.ZERO else bounds.merge(r)
			var sample=bounds.get_center()
			var before=piece.duplicate(true)
			var a=material.coordinates(sample,bounds,turns,80)
			var moved=bounds
			moved.position+=Vector2(163,59)
			ck(a.is_equal_approx(material.coordinates(sample+Vector2(163,59),moved,turns,80)),"material moves with its bag")
			var near=material.coordinates(sample+Vector2(.001,0),bounds,turns,80)
			ck(a.distance_to(near)<.00001,"no repeated tile discontinuity at logical joins")
			for p in [bounds.position,bounds.end,bounds.get_center()]:
				var uv=material.coordinates(p,bounds,turns,80)
				ck(uv.x>=0 and uv.y>=0 and uv.x<=1 and uv.y<=1,"rotated material stays in source")
			ck(before==piece,"material query cannot mutate inventory")
	# An authored point follows a 90-degree clockwise bag rotation.
	var base=Rect2(0,0,240,160)
	var rotated=Rect2(400,100,160,240)
	var point=Vector2(46,71)
	ck(material.coordinates(point,base,0,80).is_equal_approx(material.coordinates(rotated.position+Vector2(160-point.y,point.x),rotated,1,80)),"rotation carries the grain instead of remapping it")
	ck(resources.size()==5,"five bag types do not merely tint the same texture")
	print("BAG_MATERIAL_V103 ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
