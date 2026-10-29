extends SceneTree
const I=preload('res://tests/fixtures/recruitment_fixture_v114.gd')
const R=preload('res://scripts/party/recruitment_v114.gd')
const LIFE=preload('res://scripts/run/run_lifecycle.gd')
class MemoryFiles:
 extends RefCounted
 var saved=[];var opponents=0
 func save(run:Dictionary):saved.append(run.duplicate(true))
 func opponent(_run:Dictionary)->Dictionary:opponents+=1;return {'source':'memory-opponent'}
func _initialize():
 var inv=I.new();var run=inv.new_run('jiyan',114)
 assert(run.has('recruitment'))
 run.round=3;run.phase='result';run.wins=1;run.losses=1
 var old_shop=run.shop.duplicate(true);old_shop[3].locked=true;run.shop=old_shop
 var gold=run.gold;var plan=inv.plan_finish(run,1)
 assert(plan.ok and plan.run.phase=='recruit' and plan.run.round==4)
 assert(plan.run.shop==old_shop and plan.run.gold>gold)
 assert(plan.run.recruitment.candidates.size()==3)
 run=plan.run
 var frozen=run.duplicate(true);var cards=R.card_models(inv,run)
 assert(run==frozen and cards.size()==3)
 assert(cards.any(func(c):return c.usable))
 assert(not LIFE.begin(run,{},Callable()).get('ok',false))
 var chosen=R.plan_confirm(inv,run,cards[0].role_id)
 assert(chosen.ok and chosen.run.phase=='shop')
 assert(chosen.run.gold==run.gold and chosen.run.supports.size()==1)
 assert(chosen.run.shop[3]==old_shop[3])
 assert(not R.plan_confirm(inv,chosen.run,cards[0].role_id).get('ok',false))
 assert(not R.plan_confirm(inv,run,'role_9999').get('ok',false))
 assert(run==frozen)
 var files=MemoryFiles.new();var app=preload('res://scripts/run/run_application.gd').new(inv,files,null)
 var live=run.duplicate(true);var result=app.confirm_recruit(live,cards[0].role_id)
 assert(result.ok and result.opponent.source=='memory-opponent' and files.saved.size()==1 and files.opponents==1)
 assert(not app.confirm_recruit(live,cards[0].role_id).ok and files.saved.size()==1 and files.opponents==1)
 var stale=R.plan_confirm(inv,run,cards[0].role_id);run.gold+=1;var untouched=run.duplicate(true)
 assert(not app.commit(run,stale).ok and run==untouched and files.saved.size()==1)
 assert(not app.confirm_recruit(run,'role_9999').ok and run==untouched and files.saved.size()==1)
 print('V114 recruitment transactions passed')
 quit()
