extends "res://tests/regression/test_operations_v78.gd"
# V83 explicitly changes money and starters; V77 byte snapshots stay frozen.
# Keep every atomic boundary assertion and exercise the same full operation matrix.
func run_tests():
 var observed=observations()
 ck(observed==observations(),"whole operation matrix remains deterministic")
 for value in observed:
  if value is Dictionary and value.has("version"):
   ck(inv.validate_run(value),"every post-operation state legal")
   ck(value.gold>=0,"every operation preserves nonnegative money")
 boundaries()
 print("OPERATIONS_V83: ",observed.size()," observations; ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
