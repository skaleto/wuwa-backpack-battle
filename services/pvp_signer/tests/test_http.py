import http.client
import importlib.util
import io
import json
import logging
from pathlib import Path
import sys
import tempfile
import threading
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from service import Service, Settings
SPEC = importlib.util.find_spec('http_server')
if SPEC:
    from http_server import make_server


class HTTPTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(SPEC, 'HTTP adapter must exist')
        self.tmp = tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
        self.service = Service(Path(self.tmp.name) / 'state.db', Settings())
        self.addCleanup(self.service.close)
        self.server = make_server(self.service, ('127.0.0.1', 0))
        thread = threading.Thread(target=lambda: self.server.serve_forever(poll_interval=.01), daemon=True); thread.start()
        self.addCleanup(self.server.server_close)
        self.addCleanup(self.server.shutdown)
    def request(self, method, path, body=None, headers=None):
        c = http.client.HTTPConnection(*self.server.server_address, timeout=2)
        try:
            c.request(method, path, body=body, headers=headers or {})
            response = c.getresponse()
            return response.status, json.loads(response.read()), dict(response.getheaders())
        finally: c.close()
    def test_health_is_explicit_unconfigured(self):
        status, body, headers = self.request('GET', '/healthz')
        self.assertEqual((status, body['status']), (200, 'unconfigured'))
        self.assertEqual(headers['Cache-Control'], 'no-store')
    def test_large_body_rejected_before_read(self):
        status, body, _ = self.request('POST', '/sessions', '', {'Content-Length': '999999999', 'Content-Type': 'application/json'})
        self.assertEqual((status, body['error']), (413, 'body_too_large'))
    def test_invalid_json_and_shape(self):
        for body in ('{', '[]', '{"invite":"a","invite":"b"}', '{"invite":NaN}'):
            self.assertEqual(self.request('POST', '/sessions', body, {'Content-Type': 'application/json'})[0], 400)
    def test_content_type_and_chunked_rejected(self):
        self.assertEqual(self.request('POST', '/sessions', '{}', {'Content-Type': 'text/plain'})[0], 415)
        self.assertEqual(self.request('POST', '/sessions', '', {'Transfer-Encoding': 'chunked', 'Content-Type': 'application/json'})[0], 400)
    def test_session_response_has_compatible_contract(self):
        invite = self.service.create_invite()
        status, body, _ = self.request('POST', '/sessions', json.dumps({'invite': invite, 'request_id': 'r' * 32}), {'Content-Type': 'application/json'})
        self.assertEqual(status, 200)
        self.assertEqual(set(body), {'player_id', 'token'})
    def test_query_and_token_never_logged(self):
        output = io.StringIO(); handler = logging.StreamHandler(output)
        logger = logging.getLogger('pvp.http'); logger.addHandler(handler); logger.setLevel(logging.INFO)
        self.addCleanup(logger.removeHandler, handler)
        self.request('GET', '/config?token=secret-value', headers={'Authorization': 'Bearer other-secret'})
        self.assertNotIn('secret-value', output.getvalue()); self.assertNotIn('other-secret', output.getvalue())
        self.assertIn('404', output.getvalue())
    def test_invalid_token_cannot_get_ticket(self):
        status, body, _ = self.request('POST', '/storage/read-ticket', '{}', {'Authorization': 'Bearer bad', 'Content-Type': 'application/json'})
        self.assertEqual((status, body['error']), (401, 'unauthorized'))
    def test_shutdown_drains_active_session_before_closing_database(self):
        invite = self.service.create_invite()
        entered, release, database_closed = (threading.Event() for _ in range(3))
        real_dispatch = self.service.dispatch
        responses = []
        errors = []
        def paused_dispatch(*args, **kwargs):
            entered.set()
            if not release.wait(2):
                raise TimeoutError('test release not received')
            return real_dispatch(*args, **kwargs)
        self.service.dispatch = paused_dispatch
        def send_session():
            try:
                responses.append(self.request('POST', '/sessions', json.dumps({'invite': invite}), {'Content-Type': 'application/json'}))
            except Exception as error:
                errors.append(error)
        client = threading.Thread(target=send_session)
        client.start()
        self.assertTrue(entered.wait(1), 'request should be accepted before shutdown')
        def stop_like_main():
            self.server.shutdown()
            self.server.server_close()
            self.service.close()
            database_closed.set()
        stopper = threading.Thread(target=stop_like_main)
        stopper.start()
        try:
            closed_while_active = database_closed.wait(.15)
        finally:
            release.set()
            client.join(2)
            stopper.join(2)
        self.assertFalse(closed_while_active, 'SQLite closed while an accepted /sessions request was paused')
        self.assertFalse(client.is_alive())
        self.assertFalse(stopper.is_alive())
        self.assertFalse(errors)
        self.assertEqual(responses[0][0], 200)
        self.assertTrue(database_closed.is_set())

    def test_external_binding_rejected(self):
        with self.assertRaises(ValueError): make_server(self.service, ('0.0.0.0', 0))

if __name__ == '__main__': unittest.main()
