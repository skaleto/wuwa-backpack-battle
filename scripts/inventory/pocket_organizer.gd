extends RefCounted
## A pocket-only draft. Items remain in the live, valid run until one final commit.
const SESSION=preload("res://scripts/run/run_session.gd")
const C=preload("res://scripts/data/catalog.gd")
var source=""
var bags:Array=[]
var stash:Array=[]
static func allowed(run:Dictionary)->bool:
	return run.get("phase","")=="shop" and run.get("pvp",{}).get("stage","idle")=="idle"
func begin(run:Dictionary)->bool:
	if not allowed(run):return false
	source=SESSION.stamp(run);bags=run.bags.duplicate(true);stash=run.stash.duplicate(true)
	return true
func clear()->void:
	source="";bags=[];stash=[]
func preview(run:Dictionary,piece:Dictionary,destination:String,inv)->Dictionary:
	var out={"ok":false,"bags":bags.duplicate(true),"stash":stash.duplicate(true),"items":run.items}
	if not allowed(run) or source!=SESSION.stamp(run) or destination not in ["board","stash"]:return out
	if not inv.valid_piece(piece) or not C.is_tag(piece.kind,"bag"):return out
	var owned=(bags+stash).filter(func(v):return v.uid==piece.uid and v.kind==piece.kind)
	if owned.size()!=1:return out
	var placed=owned[0].duplicate(true)
	placed.merge({"x":piece.x if destination=="board" else 0,"y":piece.y if destination=="board" else 0,"rotation":piece.rotation},true)
	out.bags=out.bags.filter(func(v):return v.uid!=piece.uid)
	out.stash=out.stash.filter(func(v):return v.uid!=piece.uid)
	if destination=="board":out.bags.append(placed)
	else:out.stash.append(placed)
	out.ok=inv.bags_legal(out.bags)
	return out
func move(run:Dictionary,piece:Dictionary,destination:String,inv)->bool:
	var result=preview(run,piece,destination,inv)
	if not result.ok:return false
	bags=result.bags;stash=result.stash
	return true
func finish(run:Dictionary,inv)->Dictionary:
	var next=run.duplicate(true)
	if not allowed(run) or source!=SESSION.stamp(run):return {"ok":false}
	next.bags=bags.duplicate(true);next.stash=stash.duplicate(true)
	var cover=inv.coverage(bags)
	next.items=[]
	for item in run.items:
		if inv.occupied(item).all(func(cell):return cell in cover):next.items.append(item.duplicate(true))
		else:next.stash.append(item.duplicate(true))
	inv.clean_relay(next)
	return {"ok":inv.validate_run(next),"source":source,"run":next}
