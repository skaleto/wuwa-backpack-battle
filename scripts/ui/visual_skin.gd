extends RefCounted
## Display-only registry. No dependency on Inventory, Battle, Storage or RNG.
const C=preload("res://scripts/data/catalog.gd")
const MANIFEST_PATH="res://assets/manifest.json"
# Full-resolution visible art is pinned for one draw. Dormant pages are evicted
# first; the byte ceiling covers both 30-cell boards without preloading a skin.
const CACHE_BUDGET_BYTES=768*1024*1024
const IDLE_CACHE_BUDGET_BYTES=192*1024*1024
const CREAM=Color("f6ebd4")
const LIGHT=Color("fff2db")
const NIGHT=Color("353665")
const PLUM=Color("292247")
const BLUEBERRY=Color("aba5e9")
const MINT=Color("8bcdb6")
const SKY=Color("92cfe5")
const CORAL=Color("f18b62")
const HONEY=Color("f2c666")
const UI_NAMES=["camp_mat","camp_medallion","camp_star","camp_moon","action_start","action_team","action_secondary","bag_suede","bag_leather","bag_satin","bag_canvas","bag_webbing","travel_loop","travel_hinge","travel_ribbon","travel_plaque","travel_corner","travel_flowers","travel_label","travel_tag","travel_charm","travel_star","effect_stars","board_frame","battle_board","character_card","detail_panel","battle_button","paper_cell","price_ribbon","background","panel","button","button_primary","button_round","shop_tray","stash","portrait_frame","paper_texture","paper_fold","glyph_travel","glyph_refresh","glyph_book","glyph_move","glyph_sell","glyph_ghost","glyph_launch","glyph_menu","glyph_coin","glyph_heart","glyph_shield","glyph_energy","glyph_pause","glyph_play","glyph_rotate","glyph_lock","glyph_close","glyph_victory","glyph_defeat"]
static var current="chibi"
static var bag_style="patchwork_v129"
static var revision=0
static var preference_path="user://visual.cfg"
static var manifest:Dictionary=_read(MANIFEST_PATH)
static var alpha_bounds:Dictionary=_read("res://assets/generated/alpha-bounds.json")
static var textures:Dictionary={}
static var used_bounds:Dictionary={}
static var lru:Array=[]
static var texture_bytes:Dictionary={}
static var resident_bytes=0
static var frame_open=false
static var frame_paths:Dictionary={}
static var frame_loads=0
static var total_loads=0

static func _read(path:String)->Dictionary:
	var value=JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}

static func profile_root(args:PackedStringArray)->String:
	for name in ["visual-comparison","v60-play-1","v60-play-2","v60-play-3","release-smoke"]:
		if ("--profile="+name) in args:return "user://profiles/"+name+"/"
	return "user://"

static func configure(args:PackedStringArray,root:String)->void:
	preference_path=root+"visual.cfg"
	# Adopt the approved bags for old profiles without rewriting their run or
	# preferences on load. Old alternatives remain available via trial launchers.
	set_bag_style("patchwork_v129",false)
	for arg in args:
		if arg.begins_with("--bag-style="):set_bag_style(arg.trim_prefix("--bag-style="),false)
	current="chibi"

static func set_skin(value:String,persist:bool=true)->bool:
	if value!="chibi":return false
	if value!=current:
		current=value;revision+=1;textures.clear();lru.clear();texture_bytes.clear()
		resident_bytes=0;frame_paths.clear();frame_open=false;frame_loads=0
	if persist:_save_preferences()
	return true

static func set_bag_style(value:String,persist:bool=true)->bool:
	if value not in ["patchwork","paper","flat","fold","storybook","patchwork_v129"]:return false
	if value!=bag_style:bag_style=value;revision+=1
	if persist:_save_preferences()
	return true

static func _save_preferences()->void:
	var cfg=ConfigFile.new();cfg.load(preference_path)
	cfg.set_value("display","skin",current);cfg.set_value("display","bag_style",bag_style)
	DirAccess.make_dir_recursive_absolute(preference_path.get_base_dir());cfg.save(preference_path)

static func is_chibi()->bool:return true

static func _path(group:String,key:String)->String:
	# Missing assets deliberately retain their Q path; never substitute original art.
	return "res://"+str(manifest.get(group,{}).get(key,{}).get("path","assets/"+group+"/"+key+".png")).trim_prefix("res://")

static func item_path(kind:String)->String:
	return bag_path(kind) if C.is_tag(kind,"bag") else _path("items",kind)

static func item_angle(kind:String)->float:
	return float(manifest.get("items",{}).get(kind,{}).get("angle",0))

static func portrait_path(role:String,view:String="body")->String:
	return _path("characters",str(manifest.get("leaders",{}).get(role,role)))

static func ui_path(name:String)->String:
	return _path("ui",name)

static func ui_entry(name:String)->Dictionary:return manifest.get("ui",{}).get(name,{})

static func bag_path(kind:String)->String:return _path("bags",kind)

static func begin_frame()->void:
	frame_open=true;frame_paths.clear();frame_loads=0

static func end_frame()->void:
	frame_open=false
	var active_bytes=0
	for path in frame_paths:active_bytes+=int(texture_bytes.get(path,0))
	_trim_cache(mini(CACHE_BUDGET_BYTES,maxi(IDLE_CACHE_BUDGET_BYTES,active_bytes)),true)
	# A malformed replacement asset cannot grow the cache without a bound.
	_trim_cache(CACHE_BUDGET_BYTES,false)

static func _trim_cache(budget:int,keep_frame:bool)->void:
	for path in lru.duplicate():
		if resident_bytes<=budget:break
		if keep_frame and frame_paths.has(path):continue
		resident_bytes-=int(texture_bytes.get(path,0));texture_bytes.erase(path)
		textures.erase(path);lru.erase(path)

static func cache_metrics()->Dictionary:
	return {"resident_bytes":resident_bytes,"budget_bytes":CACHE_BUDGET_BYTES,"textures":textures.size(),"active_textures":frame_paths.size(),"frame_loads":frame_loads,"total_loads":total_loads}

static func texture(path:String)->Texture2D:
	if path.is_empty() or path=="res://":return null
	if frame_open:frame_paths[path]=true
	if textures.has(path):
		lru.erase(path);lru.append(path);return textures[path]
	if not FileAccess.file_exists(path):return null
	var value:Texture2D
	var raw:Image
	if path.ends_with(".atlas.json"):
		var metadata=_read(path)
		var source=texture(str(metadata.get("atlas","")))
		var region=metadata.get("region",[])
		if source==null or region.size()!=4:return null
		var atlas=AtlasTexture.new();atlas.atlas=source
		atlas.region=Rect2(region[0],region[1],region[2],region[3]);atlas.filter_clip=true
		value=atlas;raw=atlas.get_image();_record_bounds(path,raw)
	elif (path.begins_with("res://assets/items/") or path.begins_with("res://assets/characters/") or path.begins_with("res://assets/ui/")):
		# GPU mipmaps are rendering data only; source PNG bytes are never rewritten.
		# Decode directly, avoiding a second imported GPU texture just to read pixels.
		raw=Image.new()
		if raw.load_png_from_buffer(FileAccess.get_file_as_bytes(path))!=OK:return null
		if raw!=null:
			_record_bounds(path,raw)
			raw.generate_mipmaps();value=ImageTexture.create_from_image(raw)
	elif ResourceLoader.exists(path):
		value=load(path) as Texture2D
		if value:raw=value.get_image()
	else:
		raw=Image.load_from_file(path)
		if raw!=null:value=ImageTexture.create_from_image(raw)
	if value==null:return null
	textures[path]=value;lru.append(path)
	texture_bytes[path]=raw.get_data().size() if raw else int(value.get_width()*value.get_height()*4)
	resident_bytes+=int(texture_bytes[path]);total_loads+=1;frame_loads+=1
	if not frame_open:_trim_cache(IDLE_CACHE_BUDGET_BYTES,false)
	return value

static func bounds(path:String)->Rect2:
	if used_bounds.has(path):return used_bounds[path]
	var value=texture(path)
	if value==null:return Rect2()
	if not used_bounds.has(path):_record_bounds(path,value.get_image())
	return used_bounds.get(path,Rect2())

static func _record_bounds(path:String,pixels:Image)->void:
	if used_bounds.has(path):return
	if alpha_bounds.has(path):
		var b=alpha_bounds[path]
		used_bounds[path]=Rect2(b[0],b[1],b[2],b[3]);return
	var rect=Rect2(pixels.get_used_rect())
	if path.contains("/ui/") or path.contains("/characters/"):
		if pixels.is_compressed():pixels.decompress()
		pixels.convert(Image.FORMAT_RGBA8)
		var bytes=pixels.get_data();var width=pixels.get_width()
		var lo=Vector2i(width,pixels.get_height());var hi=Vector2i.ZERO
		for y in pixels.get_height():
			for x in width:
				if bytes[(y*width+x)*4+3]<=20:continue
				lo=lo.min(Vector2i(x,y));hi=hi.max(Vector2i(x+1,y+1))
		if hi.x>lo.x and hi.y>lo.y:rect=Rect2(Vector2(lo),Vector2(hi-lo))
	used_bounds[path]=rect

static func tone(value:Color)->Color:
	if not is_chibi():return value
	var palette={"202b3a":CREAM,"657787":BLUEBERRY,"0d1622":PLUM,"283444":Color("d9cbe9"),"172332":Color("4657a2"),"f0f1ed":PLUM,"b7c4d0":Color("756783"),"dfcfa7":Color("976724"),"aed4c6":Color("52744e"),"e7a29d":Color("ae5845"),"eef1f4":PLUM,"202834":PLUM}
	var key=Color(value,1).to_html(false)
	return Color(palette.get(key,value),value.a)

static func validate_manifest(data:Dictionary=manifest)->Array:
	var errors=[]
	for kind in C.items:
		var group="bags" if C.is_tag(kind,"bag") else "items"
		_validate_entry(data,group,kind,errors)
	for role in C.roster:_validate_entry(data,"characters",role,errors)
	for name in UI_NAMES:_validate_entry(data,"ui",name,errors)
	for leader in C.characters:
		var role=str(data.get("leaders",{}).get(leader,""))
		if role!=str(C.characters[leader].get("roster_id","")):errors.append("leader mapping: "+leader)
	return errors

static func _validate_entry(data:Dictionary,group:String,key:String,errors:Array)->void:
	var entry=data.get(group,{}).get(key,{})
	var path="res://"+str(entry.get("path","")).trim_prefix("res://")
	if entry.is_empty() or not path.begins_with("res://assets/") or not FileAccess.file_exists(path):errors.append(group+"/"+key+": missing chibi asset")
