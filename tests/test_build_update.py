import importlib.util,json,tempfile,unittest
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from build_update import IMMUTABLE,digest,require_base
class BuildUpdates(unittest.TestCase):
 def test_patch_requires_unchanged_bootstrap(self):
  with tempfile.TemporaryDirectory() as tmp:
   root=Path(tmp);stage=root/'runtime';stage.mkdir();rows=[]
   for name in IMMUTABLE:
    p=stage/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text('baseline');rows.append({'path':name,'sha256':digest(p)})
   inventory=root/'manifest.json';inventory.write_text(json.dumps(rows));require_base(stage,inventory)
   (stage/'scripts/update/bootstrap.gd').write_text('changed')
   with self.assertRaisesRegex(ValueError,'full client'):require_base(stage,inventory)
 def test_missing_trust_anchor_is_not_compatible(self):
  with tempfile.TemporaryDirectory() as tmp:
   root=Path(tmp);inventory=root/'manifest.json';inventory.write_text('[]')
   for name in IMMUTABLE:
    p=root/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text('base')
   with self.assertRaisesRegex(ValueError,'full client'):require_base(root,inventory)
if __name__=='__main__':unittest.main()
