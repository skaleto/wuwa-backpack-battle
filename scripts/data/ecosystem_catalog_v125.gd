extends RefCounted
## Explicit current profiles; historical catalog and recipes remain reconstructible.
static var spec:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/items/ecosystem.json"))
static func apply(data:Dictionary)->Dictionary:
 var out=data.duplicate(true)
 for kind in spec.updates:
  var item=out.items[kind];var n=item.get("v124",item.v75).duplicate(true)
  n.merge(spec.updates[kind].duplicate(true),true)
  publish(item,n)
 for kind in spec.new_items:
  var def=spec.new_items[kind]
  var item=out.items["echo_spectro" if def.category=="echo" else "answer"].duplicate(true)
  item.name=def.name;item.shape=def.shape.duplicate(true);item.tags=[def.category];item.stars=def.stars.duplicate(true)
  item.target="";item.element="neutral";item.released=true;item.strict_signature=false;item.demo_available=true
  for key in ["v60","v114","v124","signature_owner","strategy"]:item.erase(key)
  var n=item.v75.duplicate(true)
  for key in ["healPeriod","healAmount","shieldPeriod","shieldAmount","noisePeriod","frostPeriod","hp","emergency","openingShield","charge","hasteEvery","stamina"]:n[key]=0
  n.material_effect={};n.combo_effects=[];n.craft_only=false;n.active=true;n.inputs=[];n.leaves=[];n.depth=0
  n.merge(def.profile.duplicate(true),true);n.id=kind;n.stars=def.stars.duplicate(true);n.introduced_version=125
  n.route="组合配套";item.echo_cost=int(n.get("echo_cost",0));item.source_id="";item.source_page=""
  item.asset_path="res://assets/skins/chibi/items_v125/"+kind+".png"
  item.v75=n.duplicate(true)
  publish(item,n);out.items[kind]=item
 out.recipes.append_array(spec.recipes.duplicate(true))
 return out
static func publish(item:Dictionary,n:Dictionary)->void:
 n.hps=float(n.healAmount)/float(n.healPeriod) if n.healPeriod>0 else 0.0
 n.sps=float(n.shieldAmount)/float(n.shieldPeriod) if n.shieldPeriod>0 else 0.0
 n.noisePS=1.0/float(n.noisePeriod) if n.noisePeriod>0 else 0.0
 n.frostPS=1.0/float(n.frostPeriod) if n.frostPeriod>0 else 0.0
 item.v125=n;item.stars=n.get("stars",item.stars).duplicate(true)
 item.craft_tier=n.tier;item.canonical_cost=n.cost;item.price=n.cost;item.damage=n.damage;item.cooldown=n.cd;item.stamina=n.stamina;item.rarity=n.tier;item.craft_only=n.get("craft_only",false)
 item.desc=n.ownExtra;item.adaptation_summary="本作改编 · "+str(n.ownExtra)
