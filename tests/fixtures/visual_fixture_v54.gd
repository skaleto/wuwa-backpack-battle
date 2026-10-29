extends "res://tests/fixtures/playable_fixture_v50.gd"
const BASE_PAPER=preload("res://build/qa/ui-v54/reference/terminal_grid_v53.gd")
var baseline=false
var held_draws:Array=[]
var edge_ghost:Dictionary={}
func _draw()->void:
	held_draws=[];edge_ghost={};super._draw()
func paper_slice()->void:
	reset_slice();buttons=[];motion.modal_value=0;motion.modal_target=0
	run.bags=[piece("satchel","b1",0,0),piece("pouch","b2",3,0),piece("strip","b3",5,0),piece("corner","b4",6,1),piece("travel","b5",2,2),piece("pouch","b6",0,4)]
	run.items=[piece("w_sword","cross",1,0),piece("whiff","echo",3,1),piece("turtle","turtle",2,2)]
	run.stash=[piece("corner","stored",0,0)];run.primary="cross";run.gold=31
	for n in 5:run.shop[n]={"kind":["satchel","pouch","strip","corner","travel"][n],"locked":false}
	run.shop[5]={"kind":"verdant","locked":false}
	opponent=run.duplicate(true);opponent.leader="jiyan";opponent.supports=[]
	mouse=Vector2(1320,700);hovered={}
func _draw_board(build:Dictionary,origin:Vector2,side:int)->void:
	if not baseline:super._draw_board(build,origin,side);return
	# Archived V53 renderer on the identical current fixture, without replacing
	# the live renderer or any source asset. Only idle paper comparison uses it.
	BASE_PAPER.placement_grid(self,origin,Vector2i(I.WIDTH,I.HEIGHT),CELL,paint_alpha)
	BASE_PAPER.surface(self,origin,build.bags,CELL,"",paint_alpha,{})
	if run.phase=="shop":_draw_coord_links(build,origin)
	for item in build.items:_draw_piece(item,origin,1.0,side)
func _draw_icon(kind:String,rect:Rect2,rotation_value:int,alpha:float=1.0,selected:bool=false)->void:
	if baseline and C.is_tag(kind,"bag"):
		BASE_PAPER.thumbnail(self,Rect2(rect.position+paint_offset,rect.size),kind,rotation_value,alpha*paint_alpha);return
	super._draw_icon(kind,rect,rotation_value,alpha,selected)
func _draw_piece(item:Dictionary,origin:Vector2,alpha:float=1.0,side:int=-1,preview:bool=false,valid:bool=true)->void:
	if side==-1 and origin==Vector2.ZERO and (not dragging.is_empty() or not forge_output.is_empty()):
		var fit=_projection_for(item.kind,item.rotation,CELL)
		held_draws.append({"uid":item.uid,"rotation":item.rotation,"pose":draw_basis,"pixels":draw_basis*Transform2D(0,Vector2(item.x,item.y)*CELL)*Transform2D(fit.transform)})
	super._draw_piece(item,origin,alpha,side,preview,valid)

func _draw_stars(item:Dictionary,items:Array,origin:Vector2,active_only:bool=false,preview_build:Dictionary={})->void:
	if not dragging.is_empty() and origin==BOARD:edge_ghost=item.duplicate(true)
	super._draw_stars(item,items,origin,active_only,preview_build)
