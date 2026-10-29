"""Loopback HTTP transport; deploy behind buffering TLS reverse proxy."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import ipaddress
import json
import logging
import threading
from urllib.parse import urlsplit

from service import ApiError

MAX_BODY = 16384
LOG = logging.getLogger('pvp.http')
ROUTES = {'/healthz': 'GET', '/config': 'GET', '/sessions': 'POST', '/devices/session': 'POST',
          '/storage/read-ticket': 'POST', '/storage/upload-ticket': 'POST'}
CORS_HEADERS = frozenset(('authorization', 'content-type'))


def _pairs(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('duplicate JSON key')
        result[key] = value
    return result


def _bad_constant(value):
    raise ValueError('nonfinite JSON value')


class Handler(BaseHTTPRequestHandler):
    server_version = 'PvpSigner'
    sys_version = ''
    def setup(self):
        super().setup()
        self.connection.settimeout(10)
    def log_message(self, format, *args):
        # BaseHTTPRequestHandler includes raw request paths in its default logs.
        pass
    def send_error(self, code, message=None, explain=None):
        self._reply(code, {'error': 'invalid_http'})
    def _reply(self, status, body):
        encoded = b'' if status == 204 else json.dumps(body, separators=(',', ':')).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(encoded)))
        self.send_header('Cache-Control', 'no-store')
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('Connection', 'close')
        self.send_header('Vary', 'Origin')
        origin = self.headers.get('Origin', '')
        if len(self.headers.get_all('Origin', [])) == 1 and origin in self.server.cors_origins:
            self.send_header('Access-Control-Allow-Origin', origin)
            if status == 204:
                self.send_header('Access-Control-Allow-Methods', ROUTES[self.path])
                self.send_header('Access-Control-Allow-Headers', 'Authorization, Content-Type')
        self.end_headers()
        self.wfile.write(encoded)
        self.close_connection = True
        path = self.path if self.path in ROUTES else 'unknown'
        LOG.info('route=%s status=%d', path, status)
    def _handle(self):
        try:
            origins = self.headers.get_all('Origin', [])
            if origins:
                if len(origins) != 1 or origins[0] not in self.server.cors_origins:
                    raise ApiError(403, 'origin_not_allowed')
            if self.command == 'OPTIONS':
                if self.path not in ROUTES:
                    raise ApiError(404, 'not_found')
                requested = self.headers.get('Access-Control-Request-Method', '')
                header_names = {h.strip().lower() for h in self.headers.get('Access-Control-Request-Headers', '').split(',') if h.strip()}
                if not origins or requested != ROUTES[self.path] or not header_names <= CORS_HEADERS:
                    raise ApiError(403, 'preflight_not_allowed')
                self._reply(204, None)
                return
            ip = self.client_address[0]
            if self.server.trust_proxy:
                forwarded = self.headers.get('X-Pvp-Client-IP', '')
                try:
                    ip = str(ipaddress.ip_address(forwarded))
                except ValueError:
                    raise ApiError(400, 'invalid_proxy_ip') from None
            session_quota_charged = self.command == 'POST' and self.path in ('/sessions', '/devices/session')
            if session_quota_charged:
                # Meter attempts before reading or parsing untrusted request bodies.
                # The private transport flag below is never derived from client input.
                self.server.service.charge_session_attempt(ip)
            body = None
            if self.command == 'POST':
                if self.headers.get('Transfer-Encoding'):
                    raise ApiError(400, 'invalid_transfer_encoding')
                lengths = self.headers.get_all('Content-Length', [])
                if len(lengths) != 1 or not lengths[0].isdigit():
                    raise ApiError(400, 'invalid_content_length')
                length = int(lengths[0])
                if length > MAX_BODY:
                    raise ApiError(413, 'body_too_large')
                if self.headers.get_content_type() != 'application/json':
                    raise ApiError(415, 'json_required')
                raw = self.rfile.read(length)
                if len(raw) != length:
                    raise ApiError(400, 'incomplete_body')
                try:
                    body = json.loads(raw, object_pairs_hook=_pairs, parse_constant=_bad_constant)
                except (ValueError, UnicodeError, RecursionError):
                    raise ApiError(400, 'invalid_json') from None
                if not isinstance(body, dict):
                    raise ApiError(400, 'invalid_json')
            result = self.server.service.dispatch(self.command, self.path, body, self.headers.get('Authorization', ''), ip,
                                                  session_quota_charged=session_quota_charged)
            self._reply(200, result)
        except ApiError as error:
            self._reply(error.status, {'error': error.code})
        except (TimeoutError, ConnectionError):
            self.close_connection = True
        except Exception:
            # Do not print SDK exception messages: some include signed URLs or credentials.
            LOG.error('request_failed')
            self._reply(503, {'error': 'service_unavailable'})
    do_GET = _handle
    do_POST = _handle
    do_OPTIONS = _handle


class BoundedServer(ThreadingHTTPServer):
    # server_close must join accepted requests before main closes SQLite.
    daemon_threads = False
    block_on_close = True
    def __init__(self, *args, **kwargs):
        self.slots = threading.BoundedSemaphore(16)
        super().__init__(*args, **kwargs)
    def process_request(self, request, client_address):
        if not self.slots.acquire(blocking=False):
            self.shutdown_request(request)
            return
        try:
            super().process_request(request, client_address)
        except Exception:
            self.slots.release()
            raise
    def process_request_thread(self, request, client_address):
        try:
            super().process_request_thread(request, client_address)
        finally:
            self.slots.release()
    def handle_error(self, request, client_address):
        LOG.error('connection_failed')


def make_server(service, address=('127.0.0.1', 8430), trust_proxy=False, cors_origins=()):
    if address[0] != '127.0.0.1':
        raise ValueError('Service must bind to IPv4 loopback')
    for origin in cors_origins:
        try:
            parsed = urlsplit(origin)
            valid = (origin and '*' not in origin and all(32 < ord(c) < 127 for c in origin)
                     and parsed.scheme in ('http', 'https') and parsed.hostname
                     and parsed.netloc and parsed.username is None and parsed.password is None
                     and not parsed.path and not parsed.query and not parsed.fragment
                     and parsed.port != 0 and origin == f'{parsed.scheme}://{parsed.netloc}')
        except (ValueError, TypeError):
            valid = False
        if not valid:
            raise ValueError('CORS origins must be exact HTTP(S) origins without paths')
    server = BoundedServer(address, Handler)
    server.service, server.trust_proxy = service, trust_proxy
    server.cors_origins = tuple(cors_origins)
    return server
