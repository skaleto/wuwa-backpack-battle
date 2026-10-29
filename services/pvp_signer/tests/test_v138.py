import concurrent.futures
import http.client
import json
import socket
import subprocess
from pathlib import Path
import sys
import tempfile
import threading
import time
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from service import Service, Settings, ApiError
from http_server import make_server
from test_service import FakeSigner


class DeviceTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
        self.path = Path(self.tmp.name) / 'state.db'
        self.now = 1800000000
        self.settings = Settings(pool_ids=('pool-v134',))
        self.signer = FakeSigner()
        self.s = Service(self.path, self.settings, self.signer, lambda: self.now)
        self.addCleanup(self.s.close)
        self.body = {'installation_id': 'a' * 32, 'secret': 'b' * 64}
    def session(self, body=None, auth='', ip='127.0.0.1', service=None):
        return (service or self.s).dispatch('POST', '/devices/session', self.body if body is None else body, auth, ip)
    def rejected(self, status, call):
        with self.assertRaises(ApiError) as caught: call()
        self.assertEqual(caught.exception.status, status)
    def legacy(self):
        return self.s.dispatch('POST', '/sessions', {'invite': self.s.create_invite()})
    def test_create_retry_restart_and_no_plaintext_secrets(self):
        first = self.session()
        self.assertEqual(set(first), {'player_id', 'token', 'expires_at'})
        self.assertRegex(first['player_id'], r'^[0-9a-f]{32}$')
        self.assertRegex(first['token'], r'^[0-9a-f]{64}$')
        self.assertEqual(first['expires_at'], self.now + 86400)
        self.assertEqual(first, self.session())
        other = Service(self.path, self.settings, self.signer, lambda: self.now); self.addCleanup(other.close)
        self.assertEqual(first, self.session(service=other))
        dump = '\n'.join(self.s.db.iterdump())
        self.assertNotIn(self.body['secret'], dump)
        self.assertNotIn(first['token'], dump)
    def test_expiry_renews_same_player_and_invalidates_old_token(self):
        first = self.session()
        self.now = first['expires_at']
        renewed = self.session()
        self.assertEqual(first['player_id'], renewed['player_id'])
        self.assertNotEqual(first['token'], renewed['token'])
        self.assertEqual(renewed, self.session())
        self.rejected(401, lambda: self.s._authenticate('Bearer ' + first['token']))
        self.assertEqual(renewed['player_id'], self.s._authenticate('Bearer ' + renewed['token']))
    def test_revoke_cannot_resurrect_even_after_expiry(self):
        first = self.session(); self.s.revoke(first['player_id'])
        self.rejected(401, self.session)
        self.now = first['expires_at'] + 1
        self.rejected(401, self.session)
        self.assertEqual(self.s.db.execute('SELECT COUNT(*) FROM players').fetchone()[0], 1)
    def test_wrong_secret_does_not_rebind_with_valid_bearer(self):
        first = self.session()
        self.rejected(401, lambda: self.session(self.body | {'secret': 'c' * 64}, 'Bearer ' + first['token']))
        self.assertEqual(first, self.session())
    def test_strict_device_shape(self):
        for change in ({'installation_id': 'A' * 32}, {'installation_id': 'a' * 31}, {'secret': 'B' * 64}, {'secret': None}, {'extra': True}):
            with self.subTest(change=change): self.rejected(400, lambda: self.session(self.body | change))
        self.rejected(400, lambda: self.session({'installation_id': 'a' * 32}))
    def test_invalid_or_expired_or_revoked_legacy_does_not_register(self):
        self.rejected(401, lambda: self.session(auth='Bearer unknown'))
        self.rejected(401, lambda: self.session(auth='Basic unknown'))
        old = self.legacy(); self.now += self.settings.token_ttl
        self.rejected(401, lambda: self.session(auth='Bearer ' + old['token']))
        old2 = self.legacy(); self.s.revoke(old2['player_id'])
        self.rejected(401, lambda: self.session(auth='Bearer ' + old2['token']))
        self.assertEqual(self.s.db.execute('SELECT COUNT(*) FROM players').fetchone()[0], 2)
    def test_binding_preserves_player_and_retry_without_storing_legacy_token(self):
        old = self.legacy(); auth = 'Bearer ' + old['token']
        bound = self.session(auth=auth)
        self.assertEqual(bound['player_id'], old['player_id'])
        self.assertEqual(bound, self.session(auth=auth))
        self.assertEqual(bound, self.session())
        self.assertNotIn(old['token'], '\n'.join(self.s.db.iterdump()))
        self.rejected(401, lambda: self.session(auth='Bearer wrong'))
        self.rejected(409, lambda: self.session(self.body | {'installation_id': 'c' * 32}, 'Bearer ' + bound['token']))
    def test_bound_legacy_retry_expiry_and_revocation_are_checked(self):
        self.settings.token_ttl = 5
        old = self.legacy(); auth = 'Bearer ' + old['token']
        bound = self.session(auth=auth)
        self.now += 5
        self.rejected(401, lambda: self.session(auth=auth))
        self.assertEqual(bound, self.session())
        self.s.revoke(bound['player_id'])
        self.rejected(401, lambda: self.session(auth=auth))
    def test_invitation_recovery_rejects_migrated_player_instead_of_returning_stale_token(self):
        request = {'invite': self.s.create_invite(), 'request_id': 'r' * 32}
        old = self.s.dispatch('POST', '/sessions', request)
        bound = self.session(auth='Bearer ' + old['token'])
        self.rejected(409, lambda: self.s.dispatch('POST', '/sessions', request))
        self.assertEqual(bound, self.session())
    def test_ip_quota_bounds_new_installations_and_bad_attempts(self):
        self.settings.session_hour_limit = 2
        self.rejected(400, lambda: self.session({}))
        self.session()
        self.rejected(429, lambda: self.session(self.body | {'installation_id': 'c' * 32}))
    def test_device_quota_across_ips_and_failed_secrets(self):
        self.settings.device_hour_limit = 2
        self.session(ip='1.1.1.1')
        self.rejected(401, lambda: self.session(self.body | {'secret': 'c' * 64}, ip='2.2.2.2'))
        self.rejected(429, lambda: self.session(ip='3.3.3.3'))
        self.now += 3600
        self.session(ip='3.3.3.3')
    def test_concurrent_process_connections_share_one_identity(self):
        other = Service(self.path, self.settings, self.signer, lambda: self.now); self.addCleanup(other.close)
        with concurrent.futures.ThreadPoolExecutor(2) as pool:
            results = list(pool.map(lambda s: self.session(service=s), (self.s, other)))
        self.assertEqual(results[0], results[1])
        self.assertEqual(self.s.db.execute('SELECT COUNT(*) FROM players').fetchone()[0], 1)
    def test_wins_filter_and_cursor_boundaries(self):
        player = self.legacy(); auth = 'Bearer ' + player['token']
        def read(**kwargs): return self.s.dispatch('POST', '/storage/read-ticket', {'pool_id': 'pool-v134', 'round': 2} | kwargs, auth)
        prefix = 'test/pools/pool-v134/round/02/wins/01/'
        read(wins=1, start_after=prefix + 'd' * 32)
        self.assertEqual(self.signer.last[1]['prefix'], prefix)
        read(wins=1, continuation='a+/=')
        self.assertEqual(self.signer.last[1]['continuation-token'], 'a+/=')
        for change in ({'wins': True}, {'wins': -1}, {'wins': 2}, {'wins': '1'}, {'wins': 1, 'start_after': prefix.replace('/01/', '/00/')}, {'wins': 1, 'start_after': prefix, 'continuation': 'a'}, {'wins': 1, 'key': prefix + 'a' * 32 + '/x-' + 'b' * 64 + '.json'}):
            with self.subTest(change=change): self.rejected(400, lambda: read(**change))
    def test_device_settings_require_positive_values(self):
        for setting in ('device_token_ttl', 'device_hour_limit'):
            for value in (0, -1, True):
                with self.subTest(setting=setting, value=value), self.assertRaises(ValueError): Settings(**{setting: value})


class CorsTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
        self.s = Service(Path(self.tmp.name) / 'state.db', Settings())
        self.addCleanup(self.s.close)
        self.server = make_server(self.s, ('127.0.0.1', 0), cors_origins=('https://play.example.com',))
        self.addCleanup(self.server.server_close); self.addCleanup(self.server.shutdown)
        threading.Thread(target=lambda: self.server.serve_forever(poll_interval=.01), daemon=True).start()
    def request(self, method, path, headers=None, body=None):
        c = http.client.HTTPConnection(*self.server.server_address, timeout=2)
        try:
            c.request(method, path, body, headers or {})
            response = c.getresponse()
            return response.status, response.read(), dict(response.getheaders())
        finally: c.close()
    def test_exact_origin_success_and_error_headers(self):
        for path, status in (('/config', 200), ('/unknown', 404)):
            actual, _, headers = self.request('GET', path, {'Origin': 'https://play.example.com'})
            self.assertEqual(actual, status)
            self.assertEqual(headers['Access-Control-Allow-Origin'], 'https://play.example.com')
            self.assertEqual(headers['Vary'], 'Origin')
            self.assertNotIn('Access-Control-Allow-Credentials', headers)
    def test_unlisted_origin_cannot_mutate_or_receive_cors(self):
        for origin in ('https://play.example.com.evil', 'null', 'http://play.example.com'):
            status, _, headers = self.request('POST', '/devices/session', {'Origin': origin, 'Content-Type': 'application/json'}, json.dumps({'installation_id': 'a'*32, 'secret': 'b'*64}))
            self.assertEqual(status, 403)
            self.assertNotIn('Access-Control-Allow-Origin', headers)
        self.assertEqual(self.s.db.execute('SELECT COUNT(*) FROM players').fetchone()[0], 0)
    def test_preflight_exact_route_methods_and_headers(self):
        headers = {'Origin': 'https://play.example.com', 'Access-Control-Request-Method': 'POST', 'Access-Control-Request-Headers': 'content-type, Authorization'}
        status, raw, result = self.request('OPTIONS', '/devices/session', headers)
        self.assertEqual(status, 204); self.assertEqual(raw, b'')
        self.assertEqual(result['Access-Control-Allow-Methods'], 'POST')
        self.assertEqual(result['Access-Control-Allow-Headers'], 'Authorization, Content-Type')
        for path, extra, status in (('/config', {}, 403), ('/devices/session', {'Access-Control-Request-Method': 'DELETE'}, 403), ('/devices/session', {'Access-Control-Request-Headers': 'x-other'}, 403), ('/unknown', {}, 404)):
            self.assertEqual(self.request('OPTIONS', path, headers | extra)[0], status)
    def test_native_device_http_contract_and_default_no_origins(self):
        status, raw, headers = self.request('POST', '/devices/session', {'Content-Type': 'application/json'}, json.dumps({'installation_id': 'a'*32, 'secret': 'b'*64}))
        self.assertEqual(status, 200); self.assertIn('expires_at', json.loads(raw))
        self.assertNotIn('Access-Control-Allow-Origin', headers)
        self.server.cors_origins = ()
        self.assertEqual(self.request('GET', '/config', {'Origin': 'https://play.example.com'})[0], 403)
    def test_invalid_origin_configuration_fails_closed(self):
        for origin in ('*', 'https://*', 'https://*.example.com', 'null', 'https://play.example.com/', 'https://play.example.com/path', 'https://a@play.example.com', 'https://@play.example.com', 'https://:@play.example.com', 'https://play.example.com\r\nX-Evil: yes'):
            with self.subTest(origin=origin), self.assertRaises(ValueError):
                server = make_server(self.s, ('127.0.0.1', 0), cors_origins=(origin,))
                server.server_close()
    def test_http_session_format_errors_consume_ip_quota_before_parsing(self):
        self.s.settings.session_hour_limit = 1
        valid = json.dumps({'installation_id': 'a' * 32, 'secret': 'b' * 64})
        cases = [('{', {}, 400), ('[]', {}, 400), ('{}', {'Content-Type': 'text/plain'}, 415),
                 ('', {'Content-Length': '999999999'}, 413), ('', {'Content-Length': 'invalid'}, 400),
                 ('', {'Transfer-Encoding': 'chunked'}, 400)]
        for path in ('/devices/session', '/sessions'):
            for body, extra, expected in cases:
                with self.subTest(path=path, extra=extra, body=body):
                    with self.s.lock, self.s.db: self.s.db.execute('DELETE FROM quota')
                    headers = {'Content-Type': 'application/json'} | extra
                    self.assertEqual(self.request('POST', path, headers, body)[0], expected)
                    # Once exhausted, even malformed bodies must stop before parsing.
                    self.assertEqual(self.request('POST', path, headers, body)[0], 429)
                    self.assertEqual(self.request('POST', '/devices/session', {'Content-Type': 'application/json'}, valid)[0], 429)
                    self.assertEqual(self.s.db.execute('SELECT count FROM quota').fetchone()[0], 1)
    def test_http_success_charges_once_and_rejected_origin_charges_nothing(self):
        self.s.settings.session_hour_limit = 2
        body = json.dumps({'installation_id': 'a' * 32, 'secret': 'b' * 64})
        headers = {'Content-Type': 'application/json'}
        self.assertEqual(self.request('POST', '/devices/session', headers | {'Origin': 'https://evil.example.com'}, body)[0], 403)
        self.assertEqual(self.s.db.execute('SELECT COUNT(*) FROM quota').fetchone()[0], 0)
        self.assertEqual(self.request('POST', '/devices/session', headers, body)[0], 200)
        self.assertEqual(self.request('POST', '/devices/session', headers, body)[0], 200)
        self.assertEqual(self.request('POST', '/devices/session', headers, body)[0], 429)
        self.assertEqual(self.s.db.execute("SELECT count FROM quota WHERE subject LIKE 'session-ip:%'").fetchone()[0], 2)
    def test_format_quota_uses_validated_proxy_ip(self):
        self.s.settings.session_hour_limit = 1
        self.server.trust_proxy = True
        headers = {'Content-Type': 'application/json', 'X-Pvp-Client-IP': '192.0.2.1'}
        self.assertEqual(self.request('POST', '/devices/session', headers, '{')[0], 400)
        self.assertEqual(self.request('POST', '/devices/session', headers, '{')[0], 429)
        self.assertEqual(self.request('POST', '/devices/session', headers | {'X-Pvp-Client-IP': '192.0.2.2'}, '{')[0], 400)


class EnvironmentTests(unittest.TestCase):
    def test_main_applies_device_and_origin_environment(self):
        with tempfile.TemporaryDirectory() as directory:
            with socket.socket() as reservation:
                reservation.bind(('127.0.0.1', 0))
                port = reservation.getsockname()[1]
            process = subprocess.Popen([sys.executable, str(Path(__file__).resolve().parents[1] / 'main.py')],
                env={'PVP_DATABASE': str(Path(directory) / 'state.db'), 'PVP_PORT': str(port),
                     'PVP_DEVICE_TOKEN_TTL': '123', 'PVP_DEVICE_HOUR_LIMIT': '1',
                     'PVP_CORS_ORIGINS': ' https://env.example.com '}, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            def request(method, path, body=None, origin=None):
                connection = http.client.HTTPConnection('127.0.0.1', port, timeout=1)
                try:
                    headers = {'Content-Type': 'application/json'}
                    if origin: headers['Origin'] = origin
                    connection.request(method, path, body, headers)
                    response = connection.getresponse()
                    return response.status, json.loads(response.read()), dict(response.getheaders())
                finally: connection.close()
            try:
                for _ in range(100):
                    try:
                        status, health, _ = request('GET', '/healthz')
                        break
                    except ConnectionRefusedError:
                        if process.poll() is not None: self.fail('main exited before serving')
                        time.sleep(.02)
                else: self.fail('main did not start')
                self.assertEqual((status, health['status']), (200, 'unconfigured'))
                before = int(time.time())
                body = json.dumps({'installation_id': 'a' * 32, 'secret': 'b' * 64})
                status, session, headers = request('POST', '/devices/session', body, 'https://env.example.com')
                self.assertEqual(status, 200)
                self.assertLessEqual(before + 123, session['expires_at'])
                self.assertLessEqual(session['expires_at'], int(time.time()) + 123)
                self.assertEqual(headers['Access-Control-Allow-Origin'], 'https://env.example.com')
                self.assertEqual(request('POST', '/devices/session', body)[0], 429)
                self.assertEqual(request('GET', '/config', origin='https://other.example.com')[0], 403)
            finally:
                process.terminate()
                try: stdout, stderr = process.communicate(timeout=3)
                except subprocess.TimeoutExpired:
                    process.kill(); stdout, stderr = process.communicate()
                self.assertNotIn(b'b' * 64, stdout + stderr)


if __name__ == '__main__': unittest.main()
