import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
SPEC = importlib.util.find_spec('service')
if SPEC:
    from service import Service, Settings, ApiError


class FakeSigner:
    configured = True
    def upload(self, key, size, now):
        return {'key': key, 'url': 'https://fake.invalid/', 'fields': {'key': key}, 'expires_at': now + 300}
    def read(self, key, params, now):
        self.last = (key, params)
        return {'url': 'https://fake.invalid/', 'expires_at': now + 300}


class ServiceTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(SPEC, 'service module must implement the credential service')
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.now = 1800000000
        self.signer = FakeSigner()
        self.settings = Settings(pool_ids=('pool-v134', 'other'), identity_hour_limit=100, ip_hour_limit=200, session_hour_limit=20)
        self.s = Service(Path(self.tmp.name) / 'state.db', self.settings, self.signer, clock=lambda: self.now)
        self.addCleanup(self.s.close)
        self.invite = self.s.create_invite()
        self.session = self.s.dispatch('POST', '/sessions', {'invite': self.invite, 'request_id': 'r' * 32}, ip='127.0.0.1')
        self.auth = 'Bearer ' + self.session['token']
        self.body = dict(pool_id='pool-v134', round=2, wins=1, losses=0, run_id='run_1', sha256='a' * 64, size=1024)
    def upload(self, **changes):
        return self.s.dispatch('POST', '/storage/upload-ticket', self.body | changes, self.auth, '127.0.0.1')
    def read(self, **changes):
        return self.s.dispatch('POST', '/storage/read-ticket', dict(pool_id='pool-v134', round=2) | changes, self.auth, '127.0.0.1')
    def rejects(self, status, fn):
        with self.assertRaises(ApiError) as caught:
            fn()
        self.assertEqual(status, caught.exception.status)
    def test_session_recovery_after_response_loss(self):
        retry = self.s.dispatch('POST', '/sessions', {'invite': self.invite, 'request_id': 'r' * 32}, ip='127.0.0.1')
        self.assertEqual(self.session, retry)
        self.rejects(409, lambda: self.s.dispatch('POST', '/sessions', {'invite': self.invite, 'request_id': 'x' * 32}, ip='127.0.0.1'))
    def test_database_contains_only_credential_digests(self):
        dump = '\n'.join(self.s.db.iterdump())
        self.assertNotIn(self.invite, dump)
        self.assertNotIn(self.session['token'], dump)
        self.assertNotIn('r' * 32, dump)
    def test_config(self):
        self.assertEqual(self.s.dispatch('GET', '/config'), {'protocol': 1, 'pool_ids': ['pool-v134', 'other'], 'max_bytes': 262144})
    def test_generated_key(self):
        self.assertEqual(self.upload()['key'], f"test/pools/pool-v134/round/02/wins/01/{self.session['player_id']}/run_1-{'a' * 64}.json")
    def test_same_metadata_resigns_after_expiry(self):
        first = self.upload()
        self.now += 301
        retry = self.upload()
        self.assertEqual(first['key'], retry['key'])
        self.assertGreater(retry['expires_at'], first['expires_at'])
    def test_conflicting_hash_frozen(self):
        self.upload()
        self.rejects(409, lambda: self.upload(sha256='b' * 64))
    def test_conflicting_wins_frozen(self):
        self.upload()
        self.rejects(409, lambda: self.upload(wins=0, losses=1))
    def test_conflicting_size_frozen(self):
        self.upload()
        self.rejects(409, lambda: self.upload(size=1025))
    def test_conflicting_pool_frozen(self):
        self.upload()
        self.rejects(409, lambda: self.upload(pool_id='other'))
    def test_size_bounds(self):
        for size in (0, -1, 262145, 10**20, True, '10'):
            with self.subTest(size=size): self.rejects(400, lambda: self.upload(size=size))
    def test_wrong_round_and_records(self):
        for change in ({'round': 0}, {'round': 33}, {'round': True}, {'round': 1}, {'wins': -1, 'losses': 2}, {'wins': 2}, {'losses': True}):
            with self.subTest(change=change): self.rejects(400, lambda: self.upload(**change))
    def test_wrong_version_and_pool_traversal(self):
        for pool in ('unknown', '../pool-v134', 'pool-v134/..', 'pool-v134%2f'):
            with self.subTest(pool=pool): self.rejects(400, lambda: self.upload(pool_id=pool))
        self.rejects(400, lambda: self.upload(protocol=2))
    def test_run_id_and_hash_validation(self):
        for run in ('../x', 'x/y', '', 'x' * 65, 'x\n', 'x%2f'):
            with self.subTest(run=run): self.rejects(400, lambda: self.upload(run_id=run))
        for sha in ('A' * 63, 'g' * 64, '../x', ''):
            with self.subTest(sha=sha): self.rejects(400, lambda: self.upload(sha256=sha))
    def test_no_arbitrary_fields(self):
        self.rejects(400, lambda: self.upload(key='other/key'))
        self.rejects(400, lambda: self.read(url='https://elsewhere'))
    def test_authentication_required(self):
        for auth in ('', 'Bearer invalid', 'Basic foo'):
            self.rejects(401, lambda: self.s.dispatch('POST', '/storage/upload-ticket', self.body, auth, '127.0.0.1'))
    def test_token_revocation(self):
        self.s.revoke(self.session['player_id'])
        self.rejects(401, self.upload)
        self.rejects(401, lambda: self.s.dispatch('POST', '/sessions', {'invite': self.invite, 'request_id': 'r' * 32}, ip='127.0.0.1'))
    def test_token_expiry(self):
        self.now += self.settings.token_ttl + 1
        self.rejects(401, self.upload)
    def test_list_is_prefix_bounded(self):
        self.read(continuation='a+/=token')
        key, params = self.signer.last
        self.assertEqual(key, '')
        self.assertEqual(params, {'list-type': '2', 'prefix': 'test/pools/pool-v134/round/02/', 'max-keys': '100', 'encoding-type': 'url', 'continuation-token': 'a+/=token'})
    def test_list_start_after(self):
        key = self.upload()['key']
        self.read(start_after=key)
        self.assertEqual(self.signer.last[1]['start-after'], key)
        self.rejects(400, lambda: self.read(start_after='test/pools/other/round/02/a'))
        self.rejects(400, lambda: self.read(start_after=key, continuation='a'))
    def test_download_round_pool_and_canonical_path(self):
        key = self.upload()['key']
        self.read(key=key)
        self.assertEqual(self.signer.last, (key, {}))
        for evil in (key.replace('/02/', '/03/'), key.replace('/pool-v134/', '/other/'), key + '?acl', key + '/..', key.replace('/wins/01/', '/wins/99/'), key.replace('/wins/01/', '/wins/1/')):
            with self.subTest(key=evil): self.rejects(400, lambda: self.read(key=evil))
    def test_identity_quota(self):
        self.s.settings.identity_hour_limit = 2
        self.upload(); self.read()
        self.rejects(429, self.read)
        self.now += 3600
        self.read()
    def test_ip_quota_across_identities(self):
        self.s.settings.ip_hour_limit = 1
        self.upload()
        self.rejects(429, self.read)
    def test_bad_invite_ip_quota(self):
        self.s.settings.session_hour_limit = 2
        self.rejects(401, lambda: self.s.dispatch('POST', '/sessions', {'invite': 'invalid'}, ip='127.0.0.1'))
        self.rejects(429, lambda: self.s.dispatch('POST', '/sessions', {'invite': 'invalid'}, ip='127.0.0.1'))
    def test_unconfigured_health_and_ticket_503(self):
        self.s.signer = None
        self.assertEqual(self.s.dispatch('GET', '/healthz')['status'], 'unconfigured')
        self.rejects(503, self.upload)
        self.rejects(503, self.read)
    def test_upload_first_round(self):
        self.assertIn('/round/01/wins/00/', self.upload(round=1, wins=0)['key'])
    def test_uppercase_sha_is_normalized(self):
        self.assertEqual(self.upload()['key'], self.upload(sha256='A' * 64)['key'])

if __name__ == '__main__': unittest.main()
