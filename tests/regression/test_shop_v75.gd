extends SceneTree
const C=preload("res://scripts/data/catalog.gd")
const I=preload("res://scripts/inventory/inventory.gd")
const F=preload("res://scripts/crafting/craft.gd")
var inv=I.new();var failures=0;var checks=0
func ck(ok,label):
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():
	var run=inv.new_run("aemeath",19)
	ck(run.items.all(func(p):return p.get("paid_cost",-1)==0),"initial pieces free")
	var before=run.gold;inv.sell(run,run.items[0]);ck(run.gold==before+2,"starter can be exchanged once for two coins")
	ck(FileAccess.file_exists("res://scripts/shop/shop_v75.gd"),"new shop policy")
	if not FileAccess.file_exists("res://scripts/shop/shop_v75.gd"):quit(1);return
	var shop=load("res://scripts/shop/shop_v75.gd")
	for leader in C.selectable_leaders():
		run=inv.new_run(leader,19)
		for round_no in range(1,9):
			run.round=round_no
			for slot in 5:
				var dist=shop.distribution(run,slot,inv);var sum=0.0
				for k in dist:
					sum+=dist[k];ck(inv.shop_eligible(run,k),"eligible distribution "+k)
					ck(slot>=3 or (slot==0 and C.is_tag(k,"weapon")) or (slot==1 and C.is_tag(k,"echo")) or (slot==2 and not C.is_tag(k,"weapon") and not C.is_tag(k,"echo")),"slot category")
				ck(abs(sum-1.0)<0.000001,"normalization")
			inv.refresh(run)
			ck(inv.validate_run(run),"valid refreshed run")
			var locked=run.shop[0].duplicate();locked.locked=true;run.shop[0]=locked
			var bag=run.shop[5].duplicate();bag.locked=true;run.shop[5]=bag
			inv.refresh(run)
			ck(run.shop[0]==locked and run.shop[5]==bag,"both item and bag locks persist")
			run.shop[0].locked=false;run.shop[5].locked=false
	run=inv.new_run("aemeath",42);run.gold=100
	var k="mat_42310090";run.shop[2]={"kind":k,"locked":false}
	ck(inv.buy(run,2),"buy root")
	var p=run.stash[-1];ck(p.paid_cost==C.items[k].price,"record actual payment")
	before=run.gold;ck(inv.sell(run,p),"sell bought piece");ck(run.gold-before==int(floor(float(C.items[k].price)*.75)),"75 percent paid resale rounded down")
	var all=C.combinations.filter(func(r):return r.base=="w_sword" and r.round_min==1 and inv.signature_owned(run,r.target))
	var r=all[0];run=inv.new_run("aemeath",23);run.items=run.items.filter(func(v):return v.kind=="w_sword");run.stash=[];run.gold=100
	run.shop[2]={"kind":r.materials[0],"locked":false};ck(inv.buy(run,2),"buy needed partner")
	var paid=run.stash[0].paid_cost
	var bag=inv.make_piece("pouch","extra-bag");bag.x=3;run.bags.append(bag)
	ck(F.place_material(run,r.target,run.primary,r.materials[0],inv).ok,"adjacent actual inputs")
	var result=F.transact(run,r.target,run.primary,inv)
	ck(result.ok,"craft starter "+result.reason)
	if result.ok:ck(result.output.paid_cost==paid,"craft preserves actual sunk cost, free root stays zero")
	var a=inv.new_run("aemeath",61);var b=a.duplicate(true);inv.refresh(a);inv.refresh(b);ck(a==b,"deterministic seed")
	var specification=JSON.parse_string(FileAccess.get_file_as_string("res://data/compat/design/v75.json"))
	for k2 in specification.legacy+specification.excluded:
		if k2=="magnifier":
			ck(inv.shop_eligible(a,k2) and not C.is_tag(k2,"keepsake"),"V127 explicitly restores the useful free-access lens")
		else:ck(not inv.shop_eligible(a,k2),"excluded new supply "+k2)
	var help=inv.new_run("aemeath",109);help.items=[];help.stash=[inv.make_piece("mat_43020011","i1")];help.primary=""
	ck("w_sword" in inv.needed_materials(help),"reverse ingredient ownership requests missing base")
	var owned=inv.new_run_supply("aemeath",17,"full",0);owned.items=owned.items.filter(func(v):return v.kind=="w_sword");owned.stash=[]
	var needs=inv.needed_materials(owned);var ordinary=shop.ordinary(owned,4,inv);var assisted=shop.distribution(owned,4,inv)
	for k2 in assisted:ck(abs(assisted[k2]-(ordinary.get(k2,0.0)*.3+(.7/needs.size() if k2 in needs else 0)))<.000001,"exact 70/30 mixture "+k2)
	var rng=RandomNumberGenerator.new();rng.seed=81723;var observed={}
	for trial in 16000:
		var picked=shop.draw(assisted,rng);observed[picked]=observed.get(picked,0)+1
	for k2 in assisted:
		var expected=float(assisted[k2]);var sigma=sqrt(expected*(1-expected)/16000.0)
		ck(abs(float(observed.get(k2,0))/16000-expected)<max(.002,6*sigma),"seeded weighted draw "+k2)
	var free_run=inv.new_run("aemeath",7);var original_gold=free_run.gold
	inv.refresh(free_run,true);ck(free_run.gold==original_gold,"first refresh free")
	inv.refresh(free_run,true);ck(free_run.gold==original_gold-1,"next refresh one coin")
	var duplicate=inv.new_run("aemeath",7);duplicate.shop[2]={"kind":"daily_tea","locked":false};duplicate.shop[3]={"kind":"daily_tea","locked":false}
	ck(inv.validate_run(duplicate),"repeat offers including consumables permitted")
	var fraud=inv.new_run("aemeath",9);var weapon=fraud.items[0].duplicate(true);weapon.paid_cost=100000
	ck(inv.place(fraud,weapon),"legal move accepts coordinates")
	ck(inv.find_piece(fraud,weapon.uid).paid_cost==0,"move cannot forge purchase basis")
	var pack=fraud.bags[0].duplicate(true);pack.paid_cost=100000;pack.x=1
	ck(inv.place(fraud,pack),"move bag")
	ck(inv.find_piece(fraud,pack.uid).paid_cost==0,"bag move cannot forge purchase basis")
	ck(not inv.valid_piece({"kind":"tea","uid":"bad","x":0,"y":0,"rotation":0,"paid_cost":-1}),"reject negative cost")
	var catalog_hash=preload("res://scripts/compat/catalogue_fingerprints.gd").text(preload("res://tests/fixtures/layout.gd").published_text("res://data/catalog.json")+preload("res://tests/fixtures/layout.gd").published_text("res://scripts/data/specialty_catalog_v114.gd"))
	catalog_hash=(catalog_hash+preload("res://tests/fixtures/layout.gd").published_text("res://scripts/data/leader_catalog_v115.gd")+preload("res://tests/fixtures/layout.gd").published_text("res://scripts/party/crew_abilities_v115.gd")+preload("res://tests/fixtures/layout.gd").published_text("res://scripts/party/recruitment_v115.gd")+preload("res://tests/fixtures/layout.gd").published_text("res://scripts/data/space_catalog_v116.gd")+preload("res://tests/fixtures/layout.gd").published_text("res://scripts/inventory/pocket_rules.gd")+"resonance-v116").sha256_text()
	catalog_hash=(catalog_hash+preload("res://tests/fixtures/layout.gd").published_text("res://data/items/strategy.json")+"resonance-v124").sha256_text()
	catalog_hash=(catalog_hash+preload("res://tests/fixtures/layout.gd").published_text("res://data/items/ecosystem.json")+"resonance-v125").sha256_text()
	catalog_hash=(catalog_hash+preload("res://tests/fixtures/layout.gd").published_text("res://data/items/families.json")+"resonance-v127").sha256_text()
	catalog_hash=(catalog_hash+preload("res://tests/fixtures/layout.gd").published_text("res://data/items/solaris.json")+"resonance-v128").sha256_text()
	ck(catalog_hash==C.v128_hash,"frozen V128 catalog hash")
	catalog_hash=(catalog_hash+preload("res://tests/fixtures/layout.gd").published_text("res://data/items/pockets.json")+"pockets-v129").sha256_text()
	ck(catalog_hash==C.catalogue_hash,"live catalog hash")
	# A future two-weapon recipe must preserve the primary even when it is
	# the material input; exercise the same public transaction with a local fixture.
	var test_recipe={"id":"test_primary_material","base":"w_sword","materials":["weapon_21020013"],"target":"weapon_21020044","round_min":1,"fee":0}
	var existing=C.combinations.duplicate(true);C.combinations=[test_recipe]
	var rebind=inv.new_run("aemeath",33);rebind.items=[];rebind.stash=[];rebind.bags=[];rebind.primary="i2";rebind.serial=3
	for y in range(0,4,2):
		for x in range(0,8,2):
			var bag2=inv.make_piece("pouch","g%d_%d"%[x,y]);bag2.x=x;bag2.y=y;rebind.bags.append(bag2)
	var bas=inv.make_piece("w_sword","i1");var primary_mat=inv.make_piece("weapon_21020013","i2");primary_mat.y=1
	var unrelated=inv.make_piece("w_sword","i3");unrelated.y=3
	rebind.items=[bas,primary_mat,unrelated]
	var reb=F.transact(rebind,test_recipe.target,"i1",inv)
	ck(reb.ok,"material-primary transaction")
	if reb.ok:ck(rebind.primary==reb.output.uid,"output inherits consumed material primary")
	C.combinations=existing
	print("SHOP_V75 ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
