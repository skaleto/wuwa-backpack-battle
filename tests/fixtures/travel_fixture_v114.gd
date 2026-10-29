extends 'res://tests/fixtures/travel_fixture_v64.gd'
func _ready()->void:
 inventory=preload('res://tests/fixtures/recruitment_fixture_v114.gd').new()
 super._ready()
