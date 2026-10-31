import sys, unittest, json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from privacy import findings, public_source
from release_manifest import compute, digest, published_text, ROOT
class PrivacyTest(unittest.TestCase):
 def test_home_paths(self):
  for value in ['/Users'+'/example/private/art.png','/home'+'/example/game','C:'+r'\Users' + r'\example\game','/var'+'/folders/xx/screenshot.png']:
   self.assertTrue(findings(value.encode()))
 def test_secret(self):
  self.assertTrue(findings(('gh'+'p_'+'x'*36).encode()))
 def test_private_generator_id(self):
  self.assertTrue(findings(('exec-'+'a'*8+('-'+'b'*4)*3+'-'+'c'*12+'.png').encode()))
 def test_public_sources(self):
  self.assertFalse(findings(b'res://assets/items/example.png https://github.com/skaleto/wuwa-backpack-battle'))
  self.assertEqual(public_source(ROOT/'assets/example.png'),'assets/example.png')
  self.assertEqual(public_source(Path.home()/'private-art.png'),'private-source')
 def test_published_identity_and_rule_mutation(self):
  expected=json.loads((ROOT/'data/release-hashes.json').read_text())
  self.assertEqual(compute(),expected)
  source=published_text('assets/catalog.json')
  self.assertEqual(digest(source),expected['common_hash'])
  changed=source.replace('"price": 4','"price": 5',1)
  self.assertNotEqual(source,changed)
  self.assertNotEqual(digest(changed),expected['common_hash'])
if __name__=='__main__':unittest.main()
