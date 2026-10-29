extends RefCounted
## Display-only full-content cache. Nested/in-place edits are still detected;
## authoritative transaction stamps and commit validation remain unchanged.
var _snapshot:Dictionary={}
var _key=""
func key(value:Dictionary)->String:
	if _key.is_empty() or value!=_snapshot:
		_snapshot=value.duplicate(true)
		_key=JSON.stringify(value).sha256_text()
	return _key
