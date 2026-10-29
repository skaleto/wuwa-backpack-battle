extends SceneTree
var checks=0
var failures=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr('FAIL ',label)
func _initialize():
 var path='res://scripts/ui/presentation_stamp.gd'
 ck(FileAccess.file_exists(path),'display stamp cache is available')
 if failures:print('PRESENTATION_STAMP_V121 ',checks,' checks, ',failures,' failures');quit(1);return
 var cache=load(path).new()
 var source=JSON.parse_string(FileAccess.get_file_as_string('res://tests/fixtures/data/feedback-v120/input/hsin-round10.json'));var original=source.duplicate(true)
 var key=cache.key(source)
 ck(key==JSON.stringify(source).sha256_text(),'same canonical full-content identity')
 for n in 10:ck(cache.key(source)==key,'stable read stays stable')
 ck(source==original,'cache never owns or writes live data')
 source.items[0].x+=1
 var changed=cache.key(source)
 ck(changed!=key and changed==JSON.stringify(source).sha256_text(),'in-place nested placement invalidates without explicit notification')
 source=original.duplicate(true);source.history[0].winner=-9
 ck(cache.key(source)!=key,'history changes also invalidate; no partial dependency guessing')
 source=original.duplicate(true);source.combat.events[0].value+=1
 ck(cache.key(source)!=key,'evidence changes cannot leave old confirmation stamp')
 source=original.duplicate(true);source.new_unknown_field=true
 ck(cache.key(source)!=key,'future gameplay fields cannot silently bypass cache invalidation')
 ck(cache.key(original)==key,'returning to same full content restores identity')
 print('PRESENTATION_STAMP_V121 ',checks,' checks, ',failures,' failures');quit(1 if failures else 0)
