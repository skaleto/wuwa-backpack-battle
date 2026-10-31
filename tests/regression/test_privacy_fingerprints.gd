extends SceneTree
const H=preload("res://scripts/compat/catalogue_fingerprints.gd")
const C=preload("res://scripts/data/catalog.gd")
func _initialize()->void:
 var frozen=FileAccess.get_file_as_string("res://data/compat/catalog-v74.json")
 assert(H.text(frozen)==preload("res://scripts/compat/migration_v74_inventory.gd").HASH)
 var edited=frozen.replace('"price": 4','"price": 5')
 assert(edited!=frozen)
 assert(H.text(edited)==edited.sha256_text() and H.text(edited)!=H.text(frozen))
 assert(C.catalogue_hash=="16cf6ae5e46b9328761bf304624cd172bbf74e7da6f6bcc0a639e7c7ee46e82f")
 print("PRIVACY: published identities retained; rule edits rejected")
 quit()
