extends SceneTree
func _initialize():call_deferred('test')
func test():
	var g=preload('res://tests/fixtures/travel_fixture_v64.gd').new();root.add_child(g);await process_frame;g.set_process(false)
	var record=JSON.parse_string(FileAccess.get_file_as_string('res://tests/fixtures/data/feedback-v120/input/hsin-round10.json'));record.phase='result';record.history=[]
	g.storage.archive_completed(record)
	var current=g.run.duplicate(true);g._application().checkpoint(current)
	var original=FileAccess.get_file_as_bytes(g.storage.root_path+'run.json')
	g._action('history');g._history_action('replay')
	# Exercise the actual native window-close notification, including checkpoint.
	g._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	var same_file=FileAccess.get_file_as_bytes(g.storage.root_path+'run.json')==original
	var same_run=g.run==current
	if not same_file:printerr('FAIL window close must not overwrite the current save with historical evidence')
	if not same_run:printerr('FAIL window close must restore the current run before exit')
	var failures=int(not same_file)+int(not same_run)
	print('HISTORY_EXIT_V123 2 checks, ',failures,' failures');quit(1 if failures else 0)
