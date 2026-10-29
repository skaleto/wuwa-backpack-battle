extends SceneTree
const PATH='res://tests/fixtures/data/feedback-v120/input/hsin-round10.json'
const HASH='ffb64c408cef4c42a4b1e98a4e9018d8e3081e39ddbf8c0b0c0632c425c6db51'
const REVIEW=preload('res://scripts/battle/battle_review.gd')
var checks=0
var failures=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr('FAIL ',label)
func _initialize():
 var text=FileAccess.get_file_as_string(PATH)
 ck(text.sha256_text()==HASH,'real case remains the exact captured evidence')
 var data=JSON.parse_string(text);var before=data.duplicate(true)
 ck(data.leader=='hsin' and int(data.round)==10,'captured leader and round')
 ck(data.items.size()==15 and data.opponent.items.size()==22,'dense 37-item battle')
 var battle=data.combat
 ck(battle.events.size()==338 and battle.frames.size()==140 and is_equal_approx(battle.duration,13.9),'complete frozen event and frame stream')
 var replay=REVIEW.new()
 ck(replay.open(battle,[data,data.opponent]),'real case opens in player replay')
 for frame in battle.frames:
  ck(REVIEW.frame_at(battle,frame.time)==frame,'exact replay frame at '+str(frame.time))
 replay.play();var events=[]
 for n in 600:
  if not replay.playing:break
  events.append_array(replay.advance(1.0/30))
 ck(events==battle.events and replay.time==battle.duration,'full playback emits all 338 events once in order')
 ck(REVIEW.frame_at(replay.record,replay.time)==battle.frames[-1],'playback reaches original final frame')
 replay.seek(5.0);var part=[];replay.play()
 while replay.playing:part.append_array(replay.advance(.1))
 ck(part==battle.events.filter(func(e):return e.time>5.0),'seek resumes without repeating earlier effects')
 var shown=REVIEW.frame_at(battle,0);shown.sides.clear()
 ck(data==before and replay.record==battle and FileAccess.get_file_as_string(PATH)==text,'reading and replaying never mutate evidence')
 print('BATTLE_CASE_V120 ',checks,' checks, ',failures,' failures');quit(1 if failures else 0)
