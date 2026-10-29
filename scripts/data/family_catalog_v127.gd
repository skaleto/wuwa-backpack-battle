extends RefCounted
## Data-only projection. Historical profiles and source files remain unchanged.
static var spec:Dictionary=JSON.parse_string(FileAccess.get_file_as_string('res://data/items/families.json'))
static func apply(data:Dictionary)->Dictionary:
 var out=data.duplicate(true)
 for kind in spec.get('item_updates',{}):
  out.items[kind].merge(spec.item_updates[kind].duplicate(true),true)
 for kind in spec.updates:
  var item=out.items[kind]
  var n=item.get('v125',item.get('v124',item.get('v75',{}))).duplicate(true)
  n.merge(spec.updates[kind].duplicate(true),true)
  publish(item,n)
 for kind in spec.new_items:
  var d=spec.new_items[kind]
  var n={'id':kind,'active':true,'damage':0,'cd':0,'stamina':0,'hp':0,'emergency':0,'openingShield':0,'charge':0,'hasteEvery':0,'cleanse':0,'healPeriod':0,'healAmount':0,'shieldPeriod':0,'shieldAmount':0,'noisePeriod':0,'frostPeriod':0,'material_effect':{},'combo_effects':[],'capabilities':[],'inputs':[],'leaves':{},'depth':0,'open_round':1,'dependency_round':1,'route':'组合配套','baseText':'','supportText':'','starText':'','ownExtra':'','star_categories':[]}
  n.merge(d.profile.duplicate(true),true)
  n.stars=d.stars.duplicate(true);n.introduced_version=127
  var item={'name':d.name,'shape':d.shape.duplicate(true),'stars':d.stars.duplicate(true),'tags':[d.category],'target':'','element':'neutral','released':true,'strict_signature':false,'demo_available':true,'echo_cost':0,'source_id':'','source_page':'','canonical_effect':'','original_summary':'本作原创组合配件','effect':kind,'energy':0,'heal':0,'concerto':0,'route':n.route,'round_min':n.shop_round,'asset_path':'res://assets/skins/chibi/items_v127/'+kind+'.png'}
  publish(item,n)
  # No historical instance exists for these IDs. Compatibility readers receive
  # the same explicit clean base rather than a cloned relic's hidden ability.
  item.v75=n.duplicate(true)
  out.items[kind]=item
 out.recipes=out.recipes.filter(func(r):return r.id not in spec.remove_recipes)
 out.recipes.append_array(spec.recipes.duplicate(true))
 return out
static func publish(item:Dictionary,n:Dictionary)->void:
 n.hps=float(n.healAmount)/float(n.healPeriod) if n.healPeriod>0 else 0.0
 n.sps=float(n.shieldAmount)/float(n.shieldPeriod) if n.shieldPeriod>0 else 0.0
 n.noisePS=1.0/float(n.noisePeriod) if n.noisePeriod>0 else 0.0
 n.frostPS=1.0/float(n.frostPeriod) if n.frostPeriod>0 else 0.0
 n.extra=n.ownExtra;n.star=n.starText
 n.clocks={}
 for channel in ['heal','shield','noise','frost']:
  n.clocks[channel]={'period':n.get(channel+'Period',0),'amount':n.get(channel+'Amount',1)}
 item.v127=n;item.stars=n.get('stars',item.stars).duplicate(true)
 item.craft_tier=n.tier;item.canonical_cost=n.cost;item.price=n.cost;item.damage=n.damage;item.cooldown=n.cd;item.stamina=n.stamina;item.rarity=n.tier;item.craft_only=n.get('craft_only',false)
 item.desc=n.ownExtra;item.adaptation_summary='本作改编 · '+str(n.ownExtra)
