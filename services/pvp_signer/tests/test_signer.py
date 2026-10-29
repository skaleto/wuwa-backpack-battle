import base64
from datetime import datetime, timezone
import hashlib
import hmac
import importlib.util
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import patch
from urllib.parse import parse_qs, urlsplit
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
SPEC = importlib.util.find_spec('oss_signer')
if SPEC:
    from oss_signer import OssSigner, signer_from_env


class SignerTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(SPEC, 'OSS signing adapter must exist')
        if not importlib.util.find_spec('oss2'):
            self.skipTest('Install requirements.txt to run real SDK offline tests')
        self.now = 1800000000
        self.s = OssSigner('test-bucket', 'cn-hangzhou', 'test-access-id', 'test-secret')
    def test_exact_post_policy_fields_and_expiration(self):
        ticket = self.s.upload('test/pools/v/round/01/wins/00/player/run-hash.json', 123, self.now)
        fields = ticket['fields']
        policy = json.loads(base64.b64decode(fields['policy']))
        self.assertEqual(datetime.fromisoformat(policy['expiration'].replace('Z', '+00:00')).timestamp(), self.now + 300)
        conditions = policy['conditions']
        for name, value in {'key': ticket['key'], 'x-oss-object-acl': 'private', 'Content-Type': 'application/json', 'x-oss-content-type': 'application/json', 'x-oss-forbid-overwrite': 'true', 'success_action_status': '201'}.items():
            self.assertEqual(fields[name], value)
            self.assertIn({name: value}, conditions)
        self.assertIn(['content-length-range', 123, 123], conditions)
        self.assertIn({'bucket': 'test-bucket'}, conditions)
        for name, value in fields.items():
            if name not in ('policy', 'x-oss-signature'):
                self.assertIn({name: value}, conditions)
        self.assertNotIn('test-secret', json.dumps(ticket))
    def test_post_hmac_matches_v4_derivation(self):
        fields = self.s.upload('test/x.json', 1, self.now)['fields']
        signing = b'aliyun_v4test-secret'
        for segment in fields['x-oss-credential'].split('/')[1:]:
            signing = hmac.digest(signing, segment.encode(), 'sha256')
        self.assertEqual(fields['x-oss-signature'], hmac.new(signing, fields['policy'].encode(), hashlib.sha256).hexdigest())
    def signed(self, params):
        frozen = datetime.fromtimestamp(self.now, timezone.utc).replace(tzinfo=None)
        with patch('oss2.auth.datetime') as dt:
            dt.utcnow.return_value = frozen
            return self.s.read('', params, self.now)
    def test_list_root_and_bound_query(self):
        params = {'list-type': '2', 'prefix': 'test/pools/v/round/01/', 'max-keys': '100', 'encoding-type': 'url', 'continuation-token': 'a+/= token'}
        result = self.signed(params)
        url = urlsplit(result['url']); query = parse_qs(url.query)
        self.assertEqual(url.path, '/')
        self.assertEqual(url.netloc, 'test-bucket.oss-cn-hangzhou.aliyuncs.com')
        self.assertEqual(query['x-oss-expires'], ['300'])
        self.assertEqual(query['x-oss-signature-version'], ['OSS4-HMAC-SHA256'])
        self.assertNotIn('x-oss-additional-headers', query)
        for name, value in params.items(): self.assertEqual(query[name], [value])
        first = query['x-oss-signature']
        for name in params:
            with self.subTest(name=name):
                changed = parse_qs(urlsplit(self.signed(params | {name: params[name] + 'changed'})['url']).query)
                self.assertNotEqual(first, changed['x-oss-signature'])
        with_start = parse_qs(urlsplit(self.signed(params | {'start-after': 'test/pools/v/round/01/a'})['url']).query)
        self.assertNotEqual(first, with_start['x-oss-signature'])
    def test_download_has_no_required_extra_headers(self):
        result = self.s.read('test/a.json', {}, self.now)
        url = urlsplit(result['url'])
        self.assertEqual(url.path, '/test/a.json')
        self.assertNotIn('x-oss-additional-headers', parse_qs(url.query))
    def test_environment_fail_closed(self):
        self.assertIsNone(signer_from_env({}))
        env = {'PVP_OSS_BUCKET': 'test-bucket', 'PVP_OSS_REGION': 'cn-hangzhou', 'PVP_OSS_ACCESS_KEY_ID': 'test-id', 'PVP_OSS_ACCESS_KEY_SECRET': 'test-secret'}
        self.assertIsNone(signer_from_env(env))
        self.assertIsNotNone(signer_from_env(env | {'PVP_OSS_VERSIONING': 'never-enabled'}))
    def test_invalid_bucket_or_region_rejected(self):
        for bucket, region in [('bucket/else', 'cn-hangzhou'), ('test-bucket', 'cn-hangzhou/evil')]:
            with self.assertRaises(ValueError): OssSigner(bucket, region, 'test-id', 'test-secret')

if __name__ == '__main__': unittest.main()
