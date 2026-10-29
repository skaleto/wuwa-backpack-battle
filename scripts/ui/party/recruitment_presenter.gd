extends RefCounted
## Application-to-view adapter. Produces detached values; never saves or mutates.
const C=preload("res://scripts/data/catalog.gd")
const R=preload("res://scripts/party/recruitment.gd")
const SKIN=preload("res://scripts/ui/visual_skin.gd")
const PORTRAIT=preload("res://scripts/ui/portraits/portrait_framing.gd")
const TRADEOFFS={
	"link":"同一星位 · 同一兼容条件",
	"volley":"各自耗耐 · 快武器会等待",
	"guard":"需要治疗与产盾物品",
	"artisan":"真实消耗后返还 · 每轮一次",
	"supply":"刷新与购买仍使用金币"}
static func portrait(role:String)->Dictionary:
	var path=SKIN.portrait_path(role)
	var source=SKIN.bounds(path)
	return {"portrait":SKIN.texture(path),"portrait_source":source,"head_source":PORTRAIT.head_source(source),"role_id":role}
static func item(kind:String)->Dictionary:
	var path=SKIN.item_path(kind)
	return {"kind":kind,"name":C.items.get(kind,{}).get("name",kind),"texture":SKIN.texture(path),"source":SKIN.bounds(path)}
static func enrich(model:Dictionary)->Dictionary:
	var m=model.duplicate(true);m.merge(portrait(m.role_id))
	m.display_base=m.get("base_short",m.base_text)
	m.display_bond=m.get("bond_short",m.get("bond_text",""))
	m.display_tradeoff=m.get("tradeoff",TRADEOFFS.get(m.ability_id,""))
	m.supply_icons=m.get("specialties",[]).slice(0,2).map(func(k):return item(k))
	m.reward_icons=m.get("reward_choices",[]).map(func(r):return item(r.kind))
	m.example_icons=m.get("examples",[]).map(func(r):return item(r.kind))
	return m
static func preview(inv,run:Dictionary)->Dictionary:
	var items=[];var stash=[]
	for p in run.get("items",[]):
		var m=item(p.kind);var cells=inv.cells(p);var size=Vector2i.ONE
		for cell in cells:size=size.max(Vector2i(cell)+Vector2i.ONE)
		m.position=Vector2i(int(p.x),int(p.y));m.size=size;m.rotation=p.get("rotation",0);m.uid=p.uid;items.append(m)
	for p in run.get("stash",[]):
		var m=item(p.kind);m.rotation=p.get("rotation",0);stash.append(m)
	return {"coverage":inv.coverage(run.get("bags",[])),"items":items,"stash":stash}
static func draft(inv,run:Dictionary)->Dictionary:
	var team=[portrait(str(C.characters[run.leader].roster_id))]
	for role in run.get("supports",[]):team.append(portrait(role))
	return {"cards":R.card_models(inv,run).map(enrich),"team":team,"node":run.get("recruitment",{}).get("node",3),"background":SKIN.texture(SKIN.ui_path("background")),"preview":preview(inv,run)}
static func setup(inv,run:Dictionary)->Dictionary:
	var options=R.crew_setup_choices(inv,run)
	for rows in options.values():
		for row in rows:
			row.icons=[]
			for uid in row.get("uids",[]):
				var p=inv.find_piece(run,uid)
				if not p.is_empty():row.icons.append(item(p.kind))
			if row.config.has("return"):row.icons.append(item(row.config["return"]))
			if row.config.has("supply"):
				for k in row.config.supply.get("kinds",row.config.supply.get("pool",[])).slice(0,2):row.icons.append(item(k))
			row.selected=false
			for key in ["link","volley","guard"]:
				if row.config.has(key) and row.config[key]==run.get("recruitment",{}).get("config",{}).get(key,{} if key=="link" else []):row.selected=true
	return {"automatic":R.current(run),"team":R.team_models(inv,run).map(enrich),"options":options,"preview":preview(inv,run),"link":R.link_model(inv,run),"round":run.round,"gold":run.gold,"background":SKIN.texture(SKIN.ui_path("background")),"config":run.get("recruitment",{}).get("config",{}).duplicate(true)}
