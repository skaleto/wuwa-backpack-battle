extends RefCounted
## Exact identities of published catalogues after provenance-only redaction.
## Unknown/edited content keeps its own digest; no game rule is ignored.
static var aliases:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/compat/privacy-fingerprints.json"))
static func text(value:String)->String:
	var digest=value.sha256_text()
	return str(aliases.get(digest,digest))
