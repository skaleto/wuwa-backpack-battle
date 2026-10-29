extends RefCounted
const C=preload("res://scripts/data/catalog.gd")
const SUP=preload("res://scripts/party/supports.gd")
const T=preload("res://scripts/ui/ui_theme.gd")

static func active_sequence(g,build: Dictionary) -> Array:
	if g.run.get("phase","")=="battle" and not g.combat.is_empty():
		var side=0 if build==g.run else 1
		for i in range(mini(g.event_cursor,g.combat.events.size())-1,-1,-1):
			var ev=g.combat.events[i]
			if g.combat_time-float(ev.time)>1.0:break
			if int(ev.side)==side and ev.kind=="relay" and ev.has("sequence"):
				var result: Array=[]
				for uid in ev.sequence:
					var found=build.items.filter(func(v):return v.uid==uid)
					if not found.is_empty():result.append(found[0])
					elif str(uid).begins_with("leader-outro:"):
						var outro=g.inventory.primary_weapon(build).duplicate(true);outro.uid=uid;outro.leader_outro=true;result.append(outro)
				if not result.is_empty():return result
	return []

static func path(g,build: Dictionary) -> Array:
	var active=active_sequence(g,build)
	if not active.is_empty():return active
	var support=SUP.next(build,0)
	return support.path if not support.is_empty() else g.inventory.relay_path(build)

static func details(g,build: Dictionary) -> Dictionary:
	var support=SUP.next(build,0)
	var sequence=path(g,build)
	var lines: Array[String]=["战斗中协奏满 60 自动触发","物品保留，与合成无关"]
	if not support.is_empty():lines.append(C.roster[support.role_id].name+"变奏 → 接力 → 延奏")
	if not sequence.is_empty():lines.append("武器追加攻击 · 65% 倍率")
	if sequence.size()>1:lines.append("角色延奏攻击" if sequence[1].get("leader_outro",false) else "声骸额外释放一次技能")
	if sequence.size()>2:lines.append("随后触发信物效果")
	return {"path":sequence,"lines":lines,"support":support,"manual":not build.get("relay",[]).is_empty()}

static func draw(g) -> void:
	if not g.relay_mode or not g.overlay.is_empty():return
	var info=details(g,g.run)
	var sequence: Array=info.path
	if not g.relay_draft.is_empty():
		sequence=[]
		for uid in g.relay_draft:
			var found=g.run.items.filter(func(v):return v.uid==uid)
			if not found.is_empty():sequence.append(found[0])
	g._panel(Rect2(49,513,268,322),T.tone(T.SHELL),T.tone(T.EDGE),1,6)
	g._text("战斗接力",Vector2(68,549),23,T.tone(T.PAPER))
	g._text("协奏 60",Vector2(224,546),15,T.tone(T.JADE))
	g._text("战斗中自动触发 · 物品保留",Vector2(68,577),15,T.tone(T.MUTED))
	for n in range(mini(3,sequence.size())):
		var item=sequence[n];var x=68+n*79
		if item.get("leader_outro",false):
			if g.SKIN.is_chibi():g._chibi_portrait(g.run.leader,Rect2(x+17,598,40,40),1,true)
			else:g.draw_texture_rect(g._ensure_portrait(g.run.leader),Rect2(x+17,598,40,40),false)
		else:g._draw_icon(item.kind,Rect2(x,590,66,61),int(item.rotation))
		g._text(str(n+1),Vector2(x+26,666),14,T.tone(T.JADE))
		if n>0:g._text("›",Vector2(x-13,628),22,T.tone(T.JADE))
	if sequence.size()<2:
		g._text("再点一个相邻声骸",Vector2(68,703),17,T.tone(T.JADE))
	elif not info.support.is_empty():
		g._wrapped(C.roster[info.support.role_id].name+"变奏优先；按其武器接力",Vector2(68,697),229,15,T.tone(T.PAPER),2)
		g._text("武器 65% → 声骸技能",Vector2(68,746),15,T.tone(T.MUTED))
	else:
		g._text("武器追加攻击 · 65% 倍率",Vector2(68,701),16,T.tone(T.PAPER))
		g._text("角色延奏攻击" if sequence[1].get("leader_outro",false) else "声骸额外释放一次技能",Vector2(68,726),16,T.tone(T.PAPER))
		g._text("自动选择" if not info.manual else "已指定顺序",Vector2(68,752),14,T.tone(T.MUTED))
	g._button(Rect2(67,778,112,36),"恢复默认","relay_clear",info.manual or not g.relay_draft.is_empty())
	g._button(Rect2(188,778,112,36),"完成","relay_done")
