extends SceneTree
## Export live design projections; no save access and no duplicated rule values.
const C=preload("res://scripts/data/catalog.gd")
const P=preload("res://scripts/ui/items/item_presentation_v75.gd")
const ROOT="res://build/qa/strategy-v124/"
func save_file(name:String,body:String)->void:
	var f=FileAccess.open(ROOT+name,FileAccess.WRITE);assert(f!=null);f.store_string(body)
func _initialize():
	var costs={};var item_rows=[];var recipe_rows=[]
	for kind in C.items:
		var d=C.items[kind];var p=C.profile(kind)
		if p.get("active",false) and not p.get("craft_only",true) and not C.is_tag(kind,"bag"):costs[kind]=int(d.price)
	for iteration in C.items.size():
		var changed=false
		for r in C.combinations:
			var inputs=[r.base]+r.materials
			if not inputs.all(func(k):return costs.has(k)):continue
			var total=inputs.reduce(func(n,k):return n+costs[k],0)+int(r.get("fee",0))
			if total<int(costs.get(r.target,99999)):costs[r.target]=total;changed=true
		if not changed:break
	var design="# V124 核心物品与分支设计（当前运行配置）\n\n"
	design+="目录：`"+C.catalogue_hash+"`。数值与文字直接从当前运行配置导出；完整清单见 [165 条配方](recipes.md)，验证与边界见 [验收记录](validation.md)。\n\n"
	design+="三条主线：蓄力把伙伴活动变为重击；连动用强化击或不同声骸接力推进冷却；反击依赖实际挡伤。光噪、霜渐是跨路线效应。武器自由使用，派生攻击不回灌自然攻击计数。\n\n"
	design+="|核心|路线|伤害 / 间隔 / 体力|占格 / 星位|本体能力|星位条件与回报|\n|---|---|---|---|---|---|\n"
	for kind in C.items:
		var d=C.items[kind];var n=C.profile(kind)
		item_rows.append({"id":kind,"name":d.name,"price":d.price,"minimum_acquisition_cost":costs.get(kind,null),"shape":d.shape,"stars":d.stars,"profile":n,"effects":P.effects(kind) if not n.is_empty() else [],"chips":P.chips(kind) if not n.is_empty() else []})
		if not d.has("v124"):continue
		var own=P.support_effects(kind)+P.mechanics(kind)
		design+="|%s|%s|%s / %ss / %s|%d / %d|%s|%s|\n"%[d.name,n.role,P.number(n.damage),P.number(n.cd),P.number(n.stamina),d.shape.size(),d.stars.size()," ".join(own),n.starText]
	design+="\n## 几条可连续选择的路线\n\n- 不归孤军 → 飞景 → 镭射切变 / 灼霜 / 云琅：分别选择武器接力、霜渐强化、异种声骸。\n- 不归孤军 → 翼锋 → 永远的启明星，或转东落 → 苍鳞千嶂 / 时和岁稔：选择开场爆发、盾换伤害或强化窗口。\n- 骇行 → 钢影拳 / 袍泽之固；钢影拳 → 千般渡 / 万物持存的注释：选择挡伤反击或既有护盾支援。\n- 呼咻咻 → 青羽鹭 → 无常凶鹭；阿嗞嗞 → 紫羽鹭。声骸也能转向，不只充当武器材料。\n\n"
	design+="合成已拥有的真实材料没有回合锁。背包相邻即可选确切成品；产物放不下进储物箱。商店仍用 V122 分阶段供给。不同配方可通向同一成品，但每次只消耗所选配方输入，不凭成品名猜材料。\n\n最低成本是假设材料已能获取、不计刷新与扩容的名义材料投入，不能当作完成回合保证；合成卖价仍继承玩家真实支付成本。替代配方提供转向，不保证每条路径都最便宜。\n"
	var recipes="# V124 全部配方与投入\n\n目录：`"+C.catalogue_hash+"`。当前共 %d 条；其中 24 条为 V124 新分支，另调整 3 条旧配方的基底。名称与投入来自运行目录。\n\n"%C.combinations.size()
	recipes+="投入为输入物品各自最低获取金币之和，不含刷新、扩容或免费开局抵扣；不是售价，也不是玩家本局实际成本。‘产物最低’考虑所有替代配方和直接购买。\n\n|配方|基底 + 材料|产物|本配方投入|产物最低|后续分支|取舍|\n|---|---|---|---:|---:|---:|---|\n"
	for r in C.combinations:
		var inputs=[r.base]+r.materials;var total=inputs.reduce(func(n,k):return n+int(costs.get(k,0)),0)+int(r.get("fee",0))
		var next=C.combinations.filter(func(x):return x.base==r.target).size()
		var row=r.duplicate(true);row.minimum_input_cost=total;row.minimum_output_cost=costs.get(r.target,null);row.next_branches=next;recipe_rows.append(row)
		recipes+="|%s|%s|%s|%d|%s|%d|%s|\n"%[r.id," + ".join(inputs.map(func(k):return C.items[k].name)),C.items[r.target].name,total,str(costs.get(r.target,"—")),next,str(r.get("trade","按成品卡具体效果选择"))]
	save_file("design.md",design);save_file("recipes.md",recipes)
	save_file("runtime-catalogue.json",JSON.stringify({"catalogue_hash":C.catalogue_hash,"simulation_version":C.SIMULATION_VERSION,"items":item_rows,"recipes":recipe_rows},"\t"))
	print("EXPORT_V124 ",item_rows.size()," items / ",recipe_rows.size()," recipes");quit()
