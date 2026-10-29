extends RefCounted
## Value-only projection of already matched targets. One lit cell per instance.
## Source-relative star order keeps the representative stable through rotation.
static func markers(stars:Array,targets:Array,cell_size:float)->Array:
	var result:Array=[];var represented={}
	for cell in stars:
		var uid=""
		for target in targets:
			if cell in target.cells and not represented.has(target.uid):
				uid=target.uid;represented[uid]=true;break
		result.append({"cell":cell,"center":(Vector2(cell)+Vector2.ONE*.5)*cell_size,"state":"lit" if not uid.is_empty() else "unlit","target_uid":uid})
	return result

static func remote_markers(stars:Array,targets:Array,cell_size:float,link:Dictionary)->Array:
	# The domain has already validated/replaced the relationship. Move that one
	# displayed slot too; do not leave a second fake local highlight behind.
	if link.get("mode","")!="star":return markers(stars,targets,cell_size)
	var index=int(link.get("star",-1));var cells:Array=link.get("target_cells",[])
	if index<0 or index>=stars.size() or cells.is_empty():return markers(stars,targets,cell_size)
	var projected=stars.duplicate();projected[index]=cells[0]
	for cell in cells:
		if cell not in stars:projected[index]=cell;break
	var result=[];var positions={}
	for marker in markers(projected,targets,cell_size):
		if positions.has(marker.cell):
			if marker.state=="lit":result[positions[marker.cell]]=marker
		else:positions[marker.cell]=result.size();result.append(marker)
	return result
