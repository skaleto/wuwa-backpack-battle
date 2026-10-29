extends SceneTree
const C=preload('res://scripts/data/catalog.gd')
const I=preload('res://scripts/inventory/inventory.gd')
const SESSION=preload('res://scripts/run/run_session.gd')
const S=preload('res://scripts/storage/storage.gd')
const KINDS=['pocket_single','pocket_double','pocket_long_l','pocket_long_j']
var inv=I.new()
var checks=0
var failures=0
var saves=0
var store
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr('FAIL ',label)
func commit(run:Dictionary,plan:Dictionary)->Dictionary:
 return SESSION.commit(run,plan,inv.validate_run,func(value):saves+=1;store.save(value))
func empty_run()->Dictionary:
 var run=inv.new_run('aemeath',129);run.items=[];run.stash=[];run.primary='';run.gold=100
 return run
func at(kind:String,uid:String,x:int,y:int,rotation:int=0)->Dictionary:
 var piece=inv.make_piece(kind,uid);piece.x=x;piece.y=y;piece.rotation=rotation;return piece
func _initialize():
 store=S.new('user://qa-pockets129-transactions-'+str(OS.get_process_id())+'/')
 for kind in KINDS:
  ck(C.items.has(kind),'new kind available '+kind)
  if not C.items.has(kind):continue
  for rotation in 4:
   var run=empty_run();run.shop[5]={'kind':kind,'locked':false};store.save(run)
   var before=run.duplicate(true);var disk=FileAccess.get_file_as_bytes(store.root_path+'run.json');var save_count=saves
   var preview=at(kind,'preview',4,2,rotation)
   var shown=inv.placement_preview(run,preview,5);var plan=inv.plan_purchase_at(run,5,preview,'board')
   ck(shown.ok and plan.ok and run==before and FileAccess.get_file_as_bytes(store.root_path+'run.json')==disk,'drag preview is pure '+kind+'/'+str(rotation))
   var result=commit(run,plan)
   ck(result.ok and saves==save_count+1 and inv.validate_run(run),'one valid save per purchase '+kind+'/'+str(rotation))
   if not result.ok:continue
   ck(store.resume()==run,'saved orientation and ownership round-trip '+kind+'/'+str(rotation))
   var bought=run.bags[-1].duplicate(true)
   ck(run.gold==before.gold-int(C.items[kind].price) and run.serial==before.serial+1 and run.shop[5].is_empty() and bought.rotation==rotation,'purchase money UID orientation '+kind+'/'+str(rotation))
   ck(JSON.stringify(run)==JSON.stringify(shown.run),'preview and committed placement match')
   var committed=run.duplicate(true);save_count=saves
   ck(not commit(run,plan).ok and run==committed and saves==save_count,'duplicate release cannot buy again')
   # Put a real one-cell item into the new pocket, then move/rotate the pocket.
   var cell=inv.occupied(bought)[0];var held=at('echo_butterfly','carried',cell.x,cell.y)
   run.stash.append(held.duplicate(true));ck(commit(run,inv.plan_place(run,held)).ok,'place item inside new pocket')
   var moved=bought.duplicate(true);moved.x=5;moved.y=3;moved.rotation=(rotation+1)%4
   ck(commit(run,inv.plan_place(run,moved)).ok,'move and rotate owned pocket')
   var carried=inv.find_piece(run,'carried')
   ck(run.items.any(func(v):return v.uid=='carried') and inv.occupied(carried).all(func(v):return v in inv.occupied(moved)),'contents move with pocket as complete item')
   ck(commit(run,inv.plan_stash(run,moved)).ok,'pocket can be stashed')
   ck(run.stash.any(func(v):return v.uid==bought.uid) and run.stash.any(func(v):return v.uid=='carried') and run.items.is_empty(),'stashing pocket displaces its item exactly once')
   ck(commit(run,inv.plan_place(run,bought)).ok and run.bags.any(func(v):return v.uid==bought.uid),'stashed pocket returns to board with requested rotation')
   # Buying directly to stash keeps orientation and uses the same transaction.
   run.shop[5]={'kind':kind,'locked':false};preview.rotation=rotation
   var stash_plan=inv.plan_purchase_at(run,5,preview,'stash');var gold=run.gold
   ck(commit(run,stash_plan).ok and run.stash[-1].kind==kind and run.stash[-1].rotation==rotation and run.gold==gold-int(C.items[kind].price),'direct stash purchase '+kind+'/'+str(rotation))
   run.shop[5]={'kind':kind,'locked':false};before=run.duplicate(true);save_count=saves
   var overlap=at(kind,'preview',0,0,rotation)
   ck(not commit(run,inv.plan_purchase_at(run,5,overlap,'board')).ok and run==before and saves==save_count,'overlapping pockets reject atomically')
   var outside=at(kind,'preview',8,6,rotation)
   if inv.cells(outside).size()>1:ck(not commit(run,inv.plan_purchase_at(run,5,outside,'board')).ok and run==before,'board edge rejection keeps entire purchase unchanged')
   run.gold=0;before=run.duplicate(true)
   ck(not commit(run,inv.plan_purchase_at(run,5,preview,'stash')).ok and run==before and saves==save_count,'insufficient money never mutates ownership')
   var replacement=empty_run();replacement.shop[5]={'kind':kind,'locked':false};var previous_gold=replacement.gold
   ck(not inv.replacement_options(replacement,kind).is_empty(),'new pocket offered as an empty-bag replacement')
   ck(commit(replacement,inv.plan_replace_bag(replacement,'b1',kind,rotation)).ok and replacement.bags.size()==1 and replacement.bags[0].kind==kind and replacement.bags[0].rotation==rotation and replacement.gold==previous_gold-int(C.items[kind].price),'replacement charges exact price and preserves orientation')
 # A one-cell gap at full capacity is filled exactly; the next purchase is refused.
 var gap=empty_run();gap.bags=[];gap.shop=[{},{},{},{},{},{'kind':'pocket_single','locked':false}]
 for y in I.HEIGHT:
  for x in I.WIDTH:
   if Vector2i(x,y)==Vector2i(4,3):continue
   gap.bags.append(at('pocket_single','b'+str(x+y*I.WIDTH),x,y))
 ck(inv.validate_run(gap) and inv.purchased_capacity(gap)==62,'62-cell legal gap fixture')
 var one=at('pocket_single','preview',4,3)
 ck(commit(gap,inv.plan_purchase_at(gap,5,one,'board')).ok and inv.coverage(gap.bags).size()==63,'single pocket fills the last isolated cell')
 gap.shop[5]={'kind':'pocket_single','locked':false};var full=gap.duplicate(true);var save_count=saves
 ck(not commit(gap,inv.plan_purchase_at(gap,5,one,'stash')).ok and gap==full and saves==save_count,'capacity 63 includes stored bags and rejects 64th cell')
 # Actual item overlap is independent of the bag shape underneath.
 var swap=empty_run();swap.shop[5]={'kind':'pocket_long_l','locked':false}
 ck(commit(swap,inv.plan_purchase_at(swap,5,at('pocket_long_l','preview',4,2),'board')).ok,'long L purchased for displacement')
 var old=at('echo_butterfly','old-item',4,2);swap.stash.append(old)
 ck(commit(swap,inv.plan_place(swap,old)).ok,'first one-cell item on long L')
 var incoming=at('echo_butterfly','incoming',4,2);swap.stash.append(incoming)
 var before=swap.duplicate(true);var shown=inv.placement_preview(swap,incoming)
 ck(shown.ok and shown.displaced.size()==1 and swap==before,'displacement preview identifies whole source item')
 ck(commit(swap,inv.plan_place(swap,incoming)).ok and swap.items.any(func(v):return v.uid=='incoming') and swap.stash.any(func(v):return v.uid=='old-item'),'real swap uses new bag cells and retains displaced item')
 print('POCKETS_TRANSACTIONS_V129 ',checks,' checks, ',failures,' failures');quit(1 if failures else 0)
