extends RefCounted
## Add ordinary capacity shapes; the five published pocket definitions stay frozen.
static var spec:Dictionary=JSON.parse_string(FileAccess.get_file_as_string('res://data/items/pockets.json'))
static func apply(data:Dictionary)->Dictionary:
 var out=data.duplicate(true)
 for kind in spec:
  var d=spec[kind]
  out.items[kind]={'name':d.name,'shape':d.shape.duplicate(true),'price':d.price,'tags':['bag'],'stars':[],'round_min':1,'introduced_version':129,'cooldown':0,'damage':0,'heal':0,'energy':0,'concerto':0,'stamina':0,'element':'neutral','rarity':1,'desc':'','effect':kind,'target':'','original_summary':'本作原创容器','canonical_effect':'','source_page':'','asset_path':'assets/items/pouch.svg','v60':{'active':true,'actions':[],'activation':'none','special':{},'rows':[]},'craft_only':false,'released':true,'strict_signature':false,'route':'通用','canonical_cost':0,'echo_cost':0,'craft_tier':2}
 return out
