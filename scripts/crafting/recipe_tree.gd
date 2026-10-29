extends RefCounted
## Read-only local recipe atlas. Legacy graph helpers remain for callers.
const C=preload("res://scripts/data/catalog.gd")
const INFO=preload("res://scripts/ui/items/item_info.gd")
const T=preload("res://scripts/ui/ui_theme.gd")
const Q=preload("res://scripts/ui/items/item_quality.gd")
const VIEW=preload("res://scripts/ui/crafting/recipe_atlas_view.gd")
static var root_kind=""
static var selected=""
static var change_page=0
static var branch_page=0
static var stage_page=0
static var focus_kind=""
static var selected_recipe_id=""
static var direction="outgoing"
static var option_page=0
const OPTIONS_PER_PAGE=3

static func incoming_all(kind:String)->Array:
	return C.combinations.filter(func(recipe):return str(recipe.target)==kind)

static func outgoing(kind:String)->Array:
	return C.combinations.filter(func(recipe):return str(recipe.base)==kind or kind in recipe.materials)

static func incoming(kind:String,recipe_id:String="")->Dictionary:
	for recipe in incoming_all(kind):
		if recipe_id.is_empty() or str(recipe.id)==recipe_id:return recipe
	return {}

static func recipe_by_id(recipe_id:String)->Dictionary:
	for recipe in C.combinations:
		if str(recipe.id)==recipe_id:return recipe
	return {}

static func current_recipe()->Dictionary:
	var recipe=recipe_by_id(selected_recipe_id)
	return recipe if not recipe.is_empty() and str(recipe.target)==selected else incoming(selected)

# Compatibility projections accept old run callers; the view model uses only counts.
static func inventory_counts(run:Dictionary)->Dictionary:
	var result={}
	for item in run.get("items",[])+run.get("stash",[]):result[item.kind]=int(result.get(item.kind,0))+1
	return result

static func input_counts(run:Dictionary,recipe:Dictionary)->Array:
	return counted_inputs(inventory_counts(run),recipe)

static func counted_inputs(owned:Dictionary,recipe:Dictionary)->Array:
	var need={str(recipe.base):1};var result=[]
	for kind in recipe.materials:need[kind]=int(need.get(kind,0))+1
	for kind in need:result.append({"kind":kind,"name":str(C.items[kind].name),"owned":int(owned.get(kind,0)),"need":need[kind]})
	return result

static func option_rows(run:Dictionary,kind:String,mode:String="outgoing")->Array:
	return counted_options(inventory_counts(run),kind,mode)

static func counted_options(owned:Dictionary,kind:String,mode:String="outgoing")->Array:
	var result=[]
	for recipe in (incoming_all(kind) if mode=="incoming" else outgoing(kind)):
		var inputs=counted_inputs(owned,recipe)
		result.append({"recipe_id":str(recipe.id),"base":str(recipe.base),"target":str(recipe.target),"name":str(C.items[recipe.target].name),"inputs":inputs,"complete":inputs.all(func(row):return row.owned>=row.need),"summary":branch_summary(recipe),"next_count":outgoing(recipe.target).size()})
	return result

static func presentation(owned:Dictionary,navigation:Dictionary,can_back:bool)->Dictionary:
	var focus=str(navigation.get("focus",""))
	if not C.items.has(focus):return {}
	var mode=str(navigation.get("direction","outgoing"));var options=counted_options(owned,focus,mode)
	var pages=maxi(1,ceili(options.size()/float(OPTIONS_PER_PAGE)));var page=clampi(int(navigation.get("option_page",0)),0,pages-1)
	var all_roots=roots();var root_index=all_roots.find(str(navigation.get("root","")))
	var recipe=recipe_by_id(str(navigation.get("recipe_id","")))
	if recipe.is_empty():recipe=incoming(str(navigation.get("selected",focus)))
	var inspection=str(navigation.get("inspected",""));var result_kind=inspection if not inspection.is_empty() else str(navigation.get("selected",focus))
	var base=str(recipe.get("base","")) if inspection.is_empty() else ""
	var inputs={} if recipe.is_empty() else {"id":str(recipe.id),"target":str(recipe.target),"name":str(C.items[recipe.target].name),"inputs":counted_inputs(owned,recipe),"fee":int(recipe.get("fee",0))}
	return {"focus":{"kind":focus,"name":str(C.items[focus].name),"role":str(C.profile(focus).get("role","当前物品")),"owned":int(owned.get(focus,0))},"direction":mode,"root_previous":root_index>0,"root_next":root_index+1<all_roots.size(),"can_back":can_back,"outgoing_count":outgoing(focus).size(),"incoming_count":incoming_all(focus).size(),"selected_recipe_id":str(recipe.get("id","")),"option_page":page,"option_pages":pages,"options":options.slice(page*OPTIONS_PER_PAGE,(page+1)*OPTIONS_PER_PAGE),"recipe":inputs,"effect_page":int(navigation.get("effects",0)),"change_page":int(navigation.get("changes",0)),"result":{"kind":result_kind,"name":str(C.items[result_kind].name),"stats":D.stats(result_kind,base),"effects":D.effects(result_kind),"changes":D.changes(base,result_kind,str(recipe.get("id",""))) if not base.is_empty() else [],"has_stars":not C.items[result_kind].get("stars",[]).is_empty(),"chips":INFO.type_chips(result_kind)}}.duplicate(true)

static func branch_summary(recipe:Dictionary)->String:
	var authored=str(recipe.get("trade",""))
	var target=str(recipe.target);var profile=C.profile(target)
	if str(recipe.id).begins_with("W128-") and not authored.is_empty():return authored
	# Changed effects invalidate historical recipe trade prose as well as numbers.
	# New authored branches already describe this version; old branches use live clauses.
	if C.items[target].has("v125") or C.items[target].has("v127"):
		if (str(recipe.id).begins_with("F127-") or (str(recipe.id).begins_with("E125-") and not C.items[target].has("v127"))) and not authored.is_empty():return authored
		var live=D.V75.clauses(str(profile.get("ownExtra","")))
		if not live.is_empty():return str(live[0])
		var current=D.effects(target)
		return str(current[0]) if not current.is_empty() else "查看成品效果"
	var current_summary=D.V75.choice_summary(target)
	if not current_summary.is_empty():return current_summary
	if not authored.is_empty() and (not C.items[target].has("v124") or str(recipe.id).begins_with("V124")):return authored
	var clauses=D.V75.clauses(str(profile.get("ownExtra","")))
	if not clauses.is_empty() and not str(clauses[0]).contains("合成材料"):return str(clauses[0])
	var effects=D.effects(target)
	return str(effects[0]) if not effects.is_empty() else "查看成品效果"

static func root_of(kind:String)->String:
	var visited=[]
	while kind not in visited:
		visited.append(kind);var prior=incoming(kind)
		if prior.is_empty():return kind
		kind=prior.base
	return kind

static func roots()->Array:
	var result=[]
	for recipe in C.combinations:
		var key=root_of(recipe.base)
		if key not in result:result.append(key)
	return result

static func family(kind:String)->Array:
	var key=root_of(kind)
	return C.combinations.filter(func(recipe):return root_of(recipe.base)==key)

static func paths(kind:String)->Array:
	var result=[]
	_collect_paths(root_of(kind),[],result)
	return result

static func _collect_paths(kind:String,prefix:Array,result:Array)->void:
	if kind in prefix:return
	var path=prefix.duplicate();path.append(kind);var children=[]
	for recipe in C.combinations:
		if recipe.base==kind and recipe.target not in path and recipe.target not in children:children.append(recipe.target)
	if children.is_empty():result.append(path);return
	for child in children:_collect_paths(child,path,result)

static func choose_recipe(recipe:Dictionary)->void:
	if recipe.is_empty():return
	selected=str(recipe.target);selected_recipe_id=str(recipe.id)
	inspected="";effect_page=0;change_page=0

static func open(_g,kind:String)->void:
	if not C.items.has(kind):return
	var relevant=INFO.recipes(kind)
	if relevant.is_empty():return
	focus_kind=kind;root_kind=root_of(kind)
	if root_kind not in roots():root_kind=root_of(relevant[0].base)
	direction="outgoing" if not outgoing(kind).is_empty() else "incoming"
	var candidates=outgoing(kind) if direction=="outgoing" else incoming_all(kind)
	choose_recipe(candidates[0] if not candidates.is_empty() else relevant[0])
	option_page=0
	reveal(kind)

const A=preload("res://scripts/ui/apricot_ui.gd")
const D=preload("res://scripts/ui/items/item_description.gd")
const FRAME=Rect2(100,104,1240,756)
const GRAPH=Rect2(124,198,780,302)
const NODE_SIZE=Vector2(166,88)
static var effect_page=0
static var inspected=""
static var history:Array=[]

static func branch_pages(kind:String)->int:return maxi(1,ceili(paths(kind).size()/3.0))

static func stage_pages(kind:String)->int:
	var longest=1
	for path in paths(kind).slice(branch_page*3,branch_page*3+3):longest=maxi(longest,path.size())
	return maxi(1,ceili(longest/4.0))

static func reveal(kind:String)->void:
	var all_paths=paths(root_kind)
	for n in all_paths.size():
		var at=all_paths[n].find(kind)
		if at>=0:branch_page=n/3;stage_page=at/4;return
	branch_page=0;stage_page=0

static func coordinates(kind:String)->Dictionary:
	branch_page=clampi(branch_page,0,branch_pages(kind)-1)
	stage_page=clampi(stage_page,0,stage_pages(kind)-1)
	var visible_paths=paths(kind).slice(branch_page*3,branch_page*3+3);var positions={};var counts={}
	for row in visible_paths.size():
		var y=GRAPH.position.y+5+row*93 if visible_paths.size()>1 else GRAPH.position.y+90
		for stage in range(stage_page*4,mini(visible_paths[row].size(),stage_page*4+4)):
			var node=visible_paths[row][stage]
			if not positions.has(node):positions[node]=Vector2(GRAPH.position.x+8+(stage%4)*200,0);counts[node]=0
			positions[node].y+=y;counts[node]+=1
	for node in positions:positions[node].y/=counts[node]
	# A merge may appear at different depths. Keep legacy page nodes in distinct slots.
	var columns={}
	for node in positions:
		var x=positions[node].x
		if not columns.has(x):columns[x]=[]
		columns[x].append(node)
	for x in columns:
		var nodes=columns[x]
		nodes.sort_custom(func(a,b):return positions[a].y<positions[b].y)
		for n in nodes.size():positions[nodes[n]].y=GRAPH.position.y+5+(3-nodes.size())*46.5+n*93
	return positions

static func counts(g,recipe:Dictionary)->Array:
	return input_counts(g.run,recipe)

# Legacy game entry point only. New view receives the detached model and painter.
static func draw(g)->void:g.ITEM_PANEL.draw_atlas(g)

static func requirement_row(g,kind:String,rect:Rect2)->void:
	# Retain the familiar character association without presenting it as a lock.
	var owners=C.items[kind].get("signature_owner_ids",[]) if C.items[kind].get("strict_signature",false) else []
	if owners.is_empty():return
	A.box(g,rect,Color("ede2f7",.8),Color("c5addf",.4),10)
	var x=rect.position.x+10
	var names=[]
	for owner in owners:
		g._crew_portrait(owner,Vector2(x+14,rect.get_center().y),13,1)
		x+=34;names.append(C.roster.get(owner,{}).get("name",owner))
	g._text(" / ".join(names),Vector2(x,rect.position.y+18),15,A.INK)
	g._text("专武关联",Vector2(x,rect.position.y+36),12,A.MUTED)

static func pager(g,at:Vector2,page:int,total:int,key:String)->void:
	if total<=1:return
	A.button(g,Rect2(at,Vector2(25,23)),"‹",key+"_prev",page>0)
	g._text("%d/%d"%[page+1,total],at+Vector2(31,16),12,A.MUTED)
	A.button(g,Rect2(at+Vector2(70,0),Vector2(25,23)),"›",key+"_next",page+1<total)

static func navigation_state()->Dictionary:
	return {"root":root_kind,"selected":selected,"inspected":inspected,"effects":effect_page,"changes":change_page,"branches":branch_page,"stages":stage_page,"focus":focus_kind,"recipe_id":selected_recipe_id,"direction":direction,"option_page":option_page}

static func restore_navigation(previous:Dictionary)->void:
	root_kind=previous.root;selected=previous.selected;inspected=previous.inspected;effect_page=previous.effects;change_page=previous.changes;branch_page=previous.branches;stage_page=previous.stages
	focus_kind=previous.get("focus",root_kind);selected_recipe_id=previous.get("recipe_id","");direction=previous.get("direction","outgoing");option_page=previous.get("option_page",0)

static func remember()->void:history.append(navigation_state())

# Compatibility adapter: intents are interpreted before any game UI operation.
static func action(g,id:String)->bool:
	var request=VIEW.intent(id)
	if request.is_empty():return false
	var external=apply_navigation(request)
	if g!=null and not external.is_empty():g.ITEM_PANEL.apply_atlas_intent(g,external)
	return true

static func apply_navigation(request:Dictionary)->Dictionary:
	match str(request.get("type","")):
		"select_recipe":choose_recipe(recipe_by_id(str(request.value)))
		"focus":remember();open(null,str(request.value))
		"direction":
			direction=str(request.value);option_page=0
			var candidates=incoming_all(focus_kind) if direction=="incoming" else outgoing(focus_kind)
			if not candidates.is_empty():choose_recipe(candidates[0])
		"select_node":
			var kind=str(request.value);var candidates=incoming_all(kind)
			var local=candidates.filter(func(recipe):return recipe.base==focus_kind)
			if candidates.is_empty():inspected=kind;effect_page=0;change_page=0
			else:choose_recipe(local[0] if not local.is_empty() else candidates[0])
		"material":
			var kind=str(request.value);remember()
			if not incoming_all(kind).is_empty() or C.combinations.any(func(recipe):return recipe.base==kind):open(null,kind)
			else:inspected=kind;effect_page=0;change_page=0
		"back":
			if not history.is_empty():restore_navigation(history.pop_back())
		"root":
			var all_roots=roots();var index=clampi(all_roots.find(root_kind)+int(request.delta),0,all_roots.size()-1)
			remember();open(null,all_roots[index])
		"page":
			var delta=int(request.delta)
			match str(request.page):
				"options":option_page=maxi(0,option_page+delta)
				"branches":branch_page=maxi(0,branch_page+delta);stage_page=0
				"stages":stage_page=maxi(0,stage_page+delta)
				"changes":change_page=maxi(0,change_page+delta)
				"effects":effect_page=maxi(0,effect_page+delta)
		"close":history.clear();return {"type":"close"}
		"details":return {"type":"details","kind":selected}
	return {}

static func show_details(g,kind:String)->void:
	g.ITEM_PANEL.open_atlas_details(g,kind,navigation_state())
