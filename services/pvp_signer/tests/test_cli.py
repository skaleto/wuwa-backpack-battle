import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

class CLITests(unittest.TestCase):
    def setUp(self):
        self.assertTrue((ROOT / 'manage.py').exists(), 'Management CLI must exist')
        self.tmp = tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
        self.database = str(Path(self.tmp.name) / 'state.db')
    def run_cli(self, *args):
        result = subprocess.run([sys.executable, str(ROOT / 'manage.py'), '--database', self.database, *args], text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)
    def test_invite_creation_listing_and_revocation(self):
        created = self.run_cli('create-invite')
        self.assertGreaterEqual(len(created['invite']), 40)
        listed = self.run_cli('list-invites')
        self.assertEqual(len(listed), 1)
        self.assertNotIn(created['invite'], json.dumps(listed))
        self.run_cli('revoke-invite', listed[0]['hash'])
        self.assertEqual(self.run_cli('list-invites')[0]['revoked'], 1)
    def test_player_revocation(self):
        sys.path.insert(0, str(ROOT))
        from service import Service, Settings
        invite = self.run_cli('create-invite')['invite']
        service = Service(self.database, Settings()); self.addCleanup(service.close)
        session = service.dispatch('POST', '/sessions', {'invite': invite})
        self.run_cli('revoke-player', session['player_id'])
        self.assertEqual(service.db.execute('SELECT revoked FROM players').fetchone()[0], 1)

if __name__ == '__main__': unittest.main()
