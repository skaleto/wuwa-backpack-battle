extends RefCounted
## Opponent policy and its bounded practice cache. No file access or player writes.
const C=preload("res://scripts/data/catalog.gd")
var practice_cache:Dictionary={}
var build_practice:Callable
var practice_method:String
var simulation_version:String
func _init(builder:Callable,method:String,version:String=C.SIMULATION_VERSION):
	build_practice=builder;practice_method=method;simulation_version=version
func choose(round_number:int,seed_value:int,ghosts:Array,owner:String,pool_mode:String="full",supply_version:int=0)->Dictionary:
	if round_number<=3:return practice(round_number,seed_value,pool_mode,supply_version)
	var candidates=ghosts.filter(func(g):return g.get("pool_mode","full")==pool_mode and int(g.get("supply_version",0))==supply_version and g.get("simulation_version","")==simulation_version and not g.get("inactive",false) and g.get("owner","")!=owner and absi(int(g.round)-round_number)<=1)
	candidates.sort_custom(func(a,b):return absi(int(a.round)-round_number)<absi(int(b.round)-round_number))
	if not candidates.is_empty():
		var ghost=candidates[0].duplicate(true);ghost.source="saved";return ghost
	return practice(round_number,seed_value,pool_mode,supply_version)
func practice(round_number:int,seed_value:int,pool_mode:String="full",supply_version:int=0)->Dictionary:
	var key="%s:%s:%s:%s:%d:%d:%d"%[C.catalogue_hash,simulation_version,practice_method,pool_mode,round_number,seed_value%31,supply_version]
	if not practice_cache.has(key):
		if practice_cache.size()>=32:practice_cache.erase(practice_cache.keys()[0])
		practice_cache[key]=build_practice.call(round_number,seed_value%31,pool_mode,supply_version) if supply_version!=0 else build_practice.call(round_number,seed_value%31,pool_mode) if pool_mode!="full" else build_practice.call(round_number,seed_value%31)
	return practice_cache[key].duplicate(true)
