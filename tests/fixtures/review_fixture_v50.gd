extends "res://tests/fixtures/playable_fixture_v50.gd"
# Observe actual draw calls, so tests cannot pass on unused presentation helpers.
var drawn_boards:Array=[]
var drawn_text:Array=[]
var drawn_ghost:Dictionary={}
func reset_observations()->void:
	drawn_boards=[];drawn_text=[];drawn_ghost={}
func _draw_board(build:Dictionary,origin:Vector2,side:int)->void:
	drawn_boards.append({"side":side,"pose":draw_basis,"corner":draw_basis*origin})
	super._draw_board(build,origin,side)
func _draw_piece(item:Dictionary,origin:Vector2,alpha:float=1.0,side:int=-1,preview:bool=false,valid:bool=true)->void:
	if item.get("uid","")=="forge-preview":
		drawn_ghost={"pose":draw_basis,"corner":draw_basis*(origin+Vector2(item.x,item.y)*CELL)}
	super._draw_piece(item,origin,alpha,side,preview,valid)
func _text(value:String,pos:Vector2,size:int,color:Color)->void:
	drawn_text.append({"value":value,"pos":pos})
	super._text(value,pos,size,color)
