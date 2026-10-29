extends SceneTree
const G=preload('res://scripts/game.gd')
const S=preload('res://scripts/storage/storage.gd')
const P=preload('res://scripts/online/async_pvp.gd')
var failures=0
var checks=0
func ck(value,label):
 checks+=1
 if not value:failures+=1;printerr('FAIL ',label)
func _initialize():call_deferred('test')
func test():
 ck(ProjectSettings.get_setting('application/config/name')=='索拉里斯大乱斗','approved game name')
 ck(ProjectSettings.get_setting('application/config/custom_user_dir_name')=='ResonancePackNextV60','rename keeps existing save directory')
 var g=G.new();g.storage=S.new('user://qa-v135-'+P.random_id()+'/');root.add_child(g)
 ck(not g.has_method('_open_online_settings'),'no player-facing credential dialog')
 g._action('choose:lynae');g._action('camp:practice:enter')
 ck(g.screen=='game' and g.run.get('leader')=='lynae','human button directly starts selected leader')
 if g.screen!='game':g.queue_free();print('LOBBY_V135 ',checks,' checks, ',failures,' failures');quit(1);return
 var human=g.run.duplicate(true);g._action('home')
 g._action('camp:async:enter')
 ck(g.screen=='game' and g.run.get('mode')=='async' and g.opponent.is_empty(),'online button directly starts separate async run')
 var online=g.run.duplicate(true);g._action('home')
 g._action('choose:zani');g._action('camp:practice:resume')
 ck(g.run==human,'mode entry resumes correct save instead of overwriting with selected leader')
 g._action('home');g._action('camp:async:enter')
 ck(g.run==online,'online progress preserved across mode switches')
 g._action('home');g._action('camp:practice:new')
 ck(g.run.leader=='zani' and g.run!=human,'explicit new uses current character')
 g._action('home');g._action('camp:async:history')
 ck(g.game_mode=='async' and g.screen=='camp' and g.overlay=='history','history selects correct mode without starting run')
 g.overlay='';g._action('camp:async:bad')
 ck(g.screen=='camp','unknown lobby action cannot start game')
 g.queue_free();await process_frame;await create_timer(.3).timeout
 print('LOBBY_V135 ',checks,' checks, ',failures,' failures');quit(1 if failures else 0)
