extends SceneTree
const FORM=preload("res://scripts/ui/pockets/bag_form.gd")
const T=preload("res://scripts/ui/pockets/terminal_grid.gd")
var checks=0
var failures=0
func ck(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func bag(kind:String,uid:String,x:int,y:int,rotation:int=0)->Dictionary:
	return {"kind":kind,"uid":uid,"x":x,"y":y,"rotation":rotation}
func _initialize()->void:
	# This suite exercises the retained V107 contact projection specifically.
	T.SKIN.set_bag_style("patchwork",false)
	var bags=T.form_bags([bag("satchel","left",0,0),bag("pouch","right",3,0)])
	var owner={}
	for b in bags:
		for cell in b.cells:owner[cell]=b.uid
	var center=FORM._joining_offset(Vector2(240,80),"left",owner,80)
	var tip=FORM._joining_offset(Vector2(240,0),"left",owner,80)
	ck(center.is_equal_approx(Vector2(-24,0)),"shared middle retains lining without thick walls")
	ck(tip.is_equal_approx(Vector2(-12,0)),"exposed seam end keeps half the original rim instead of pulling it flat")
	ck(FORM._joining_offset(Vector2.ZERO,"left",owner,80)==Vector2.ZERO,"unjoined exterior is unchanged")
	var junction={Vector2i(0,0):"a",Vector2i(1,0):"b",Vector2i(0,1):"c",Vector2i(1,1):"d"}
	ck(FORM._joining_offset(Vector2(80,80),"a",junction,80).is_equal_approx(Vector2(-24,-24)),"interior junction does not preserve an exposed corner fragment")
	var path="res://scripts/ui/pockets/bag_contacts.gd"
	ck(FileAccess.file_exists(path),"contact view exists")
	if FileAccess.file_exists(path):
		var contacts=load(path);var before=bags.duplicate(true)
		var edges=contacts.segments(bags)
		ck(edges.size()==1,"two unit joins merge into one contact")
		if edges.size()==1:
			ck(edges[0].a==Vector2(3,0) and edges[0].b==Vector2(3,2),"contact follows the full shared side")
		var swapped=bags.duplicate(true);swapped.reverse()
		ck(contacts.segments(swapped)==edges,"bag draw order cannot change contact geometry")
		ck(contacts.segments(T.form_bags([bag("satchel","a",0,0),bag("pouch","b",4,0)])).is_empty(),"a gap does not gain a connecting shadow")
		ck(contacts.segments(T.form_bags([bag("pouch","a",0,0),bag("pouch","b",2,2)])).is_empty(),"corner-only touching does not gain a shared side")
		for turns in 4:
			var first=bag("satchel","a",0,0,turns);var width=3 if turns%2==0 else 2
			var rotated=T.form_bags([first,bag("pouch","b",width,0,turns)])
			var e=contacts.segments(rotated)
			ck(e.size()==1,"rotated containers retain a single shared contact")
			if e.size()==1:ck(e[0].a.x==width and e[0].b.x==width,"rotated join matches logical ownership")
		var four=T.form_bags([bag("pouch","a",0,0),bag("pouch","b",2,0),bag("pouch","c",0,2),bag("pouch","d",2,2)])
		var unique={}
		for e in contacts.segments(four):
			var key=str(e.a)+str(e.b)
			ck(not unique.has(key),"four-way contact never doubles a segment");unique[key]=true
		ck(unique.size()==4,"four-way junction has four arms, no extra central marker")
		ck(bags==before,"projection does not change bag data")
	print("BAG_CONTACTS_V107 ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
