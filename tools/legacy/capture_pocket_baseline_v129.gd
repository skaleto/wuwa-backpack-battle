extends SceneTree
## One-time pre-change capture; never rerun to bless a changed historical result.
func _initialize():
 var path='res://tests/fixtures/data/pockets-v129/baseline/supply-v128.json'
 if FileAccess.file_exists(path):push_error('Frozen baseline already exists');quit(1);return
 DirAccess.make_dir_recursive_absolute('res://build/qa/pockets-v129/baseline')
 var rows=preload('res://tests/scenarios/pocket_supply_trace_v129.gd').sample()
 FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(rows))
 print('POCKET_BASELINE_V129 ',rows.size(),' historical traces');quit()
