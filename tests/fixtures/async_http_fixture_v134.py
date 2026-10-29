#!/usr/bin/env python3
"""TEST ONLY: real credential service plus in-memory fake OSS, all on loopback.

Usage: python3 tests/fixtures/async_http_fixture_v134.py --state /tmp/pvp-fixture.json --pool HEX64
This fixture is not an OSS security/integration test and never accesses cloud resources.
"""
import argparse
import base64
from email import policy
from email.parser import BytesParser
from http.server import BaseHTTPRequestHandler
import json
import os
from pathlib import Path
import re
import signal
import sys
import tempfile
import threading
import time
from urllib.parse import parse_qs, quote, urlencode, urlsplit
import xml.etree.ElementTree as ET

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'services' / 'pvp_signer'))
from http_server import BoundedServer, make_server
from service import MAX_BYTES, Service, Settings

MAX_MULTIPART = MAX_BYTES + 32768
MAX_TOTAL = 16 * 1024 * 1024
PAGE_SIZE = 2


class FixtureSigner:
    configured = True
    def __init__(self, base_url):
        self.base_url = base_url
    def upload(self, key, size, now):
        return {
            'key': key,
            'url': self.base_url + '/upload?' + urlencode({'key': key, 'size': size, 'expires': now + 300}),
            'fields': {'key': key, 'Content-Type': 'application/json', 'x-oss-object-acl': 'private', 'x-oss-forbid-overwrite': 'true'},
            'expires_at': now + 300,
        }
    def read(self, key, params, now):
        query = {'key': key} if key else dict(params)
        query['expires'] = str(now + 300)
        return {'url': self.base_url + ('/object?' if key else '/list?') + urlencode(query), 'expires_at': now + 300}


class FixtureError(Exception):
    def __init__(self, status, code):
        self.status, self.code = status, code


class FakeOSSHandler(BaseHTTPRequestHandler):
    def setup(self):
        super().setup()
        self.connection.settimeout(3)
    def log_message(self, format, *args):
        pass
    def send_error(self, code, message=None, explain=None):
        self.reply(code, b'{"error":"invalid_http"}', 'application/json')
    def reply(self, status, data=b'', content_type='application/json'):
        self.send_response(status)
        self.send_header('Content-Type', content_type)
        self.send_header('Content-Length', str(len(data)))
        self.send_header('Cache-Control', 'no-store')
        self.send_header('Connection', 'close')
        self.end_headers()
        self.wfile.write(data)
        self.close_connection = True
    def route(self):
        if len(self.path) > 8192:
            raise FixtureError(400, 'invalid_path')
        parsed = urlsplit(self.path)
        query = parse_qs(parsed.query, keep_blank_values=True, max_num_fields=12)
        if any(len(values) != 1 for values in query.values()):
            raise FixtureError(400, 'duplicate_query')
        query = {name: values[0] for name, values in query.items()}
        if int(query.get('expires', '0')) < time.time():
            raise FixtureError(403, 'expired_fixture_ticket')
        if self.command == 'POST' and parsed.path == '/upload':
            self.upload(query)
        elif self.command == 'GET' and parsed.path == '/object':
            with self.server.object_lock:
                data = self.server.objects.get(query.get('key', ''))
            if data is None:
                raise FixtureError(404, 'NoSuchKey')
            self.reply(200, data)
        elif self.command == 'GET' and parsed.path == '/list':
            self.list_objects(query)
        else:
            raise FixtureError(404, 'not_found')
    def handle_method(self):
        try:
            self.route()
        except FixtureError as error:
            self.reply(error.status, json.dumps({'error': error.code}).encode())
        except (ValueError, UnicodeError, KeyError):
            self.reply(400, b'{"error":"invalid_request"}')
        except (TimeoutError, ConnectionError):
            self.close_connection = True
    do_POST = handle_method
    do_GET = handle_method
    def upload(self, query):
        lengths = self.headers.get_all('Content-Length', [])
        if self.headers.get('Transfer-Encoding') or len(lengths) != 1 or not lengths[0].isdigit():
            raise FixtureError(400, 'invalid_length')
        length = int(lengths[0])
        if not 1 <= length <= MAX_MULTIPART:
            raise FixtureError(413, 'body_too_large')
        if self.headers.get_content_type() != 'multipart/form-data':
            raise FixtureError(415, 'multipart_required')
        raw = self.rfile.read(length)
        if len(raw) != length:
            raise FixtureError(400, 'incomplete_body')
        mime = BytesParser(policy=policy.default).parsebytes(
            b'Content-Type: ' + self.headers['Content-Type'].encode('ascii') + b'\r\nMIME-Version: 1.0\r\n\r\n' + raw)
        if not mime.is_multipart() or mime.defects:
            raise FixtureError(400, 'invalid_multipart')
        fields = {}
        parts = list(mime.iter_parts())
        if not 1 <= len(parts) <= 20:
            raise FixtureError(400, 'too_many_parts')
        for part in parts:
            name = part.get_param('name', header='content-disposition')
            if part.get_content_disposition() != 'form-data' or not name or name in fields or part.is_multipart():
                raise FixtureError(400, 'invalid_part')
            fields[name] = part.get_payload(decode=True)
        key = fields.get('key', b'').decode('utf-8')
        data = fields.get('file')
        if not key or key != query.get('key') or data is None or parts[-1].get_param('name', header='content-disposition') != 'file':
            raise FixtureError(400, 'key_or_file_mismatch')
        if not 1 <= len(data) <= MAX_BYTES or len(data) != int(query['size']):
            raise FixtureError(413, 'size_mismatch')
        if fields.get('x-oss-forbid-overwrite') != b'true' or fields.get('x-oss-object-acl') != b'private' or fields.get('Content-Type') != b'application/json':
            raise FixtureError(400, 'fixture_fields_mismatch')
        with self.server.object_lock:
            if key in self.server.objects:
                raise FixtureError(409, 'FileAlreadyExists')
            if len(self.server.objects) >= 256 or sum(map(len, self.server.objects.values())) + len(data) > MAX_TOTAL:
                raise FixtureError(413, 'fixture_capacity')
            self.server.objects[key] = data
        result = ET.Element('PostResponse')
        ET.SubElement(result, 'Key').text = key
        self.reply(201, ET.tostring(result, encoding='utf-8'), 'application/xml')
    def list_objects(self, query):
        prefix = query.get('prefix', '')
        if query.get('list-type') != '2' or query.get('encoding-type') != 'url' or not prefix.startswith('test/pools/'):
            raise FixtureError(400, 'invalid_list')
        start_after = query.get('start-after', '')
        if 'continuation-token' in query:
            try:
                start_after = base64.b64decode(query['continuation-token'], validate=True).decode('utf-8')
            except (ValueError, UnicodeError):
                raise FixtureError(400, 'invalid_continuation') from None
            if not start_after.startswith(prefix):
                raise FixtureError(400, 'continuation_prefix')
        with self.server.object_lock:
            keys = sorted(k for k in self.server.objects if k.startswith(prefix) and k > start_after)
            selected = [(key, len(self.server.objects[key])) for key in keys[:PAGE_SIZE]]
        truncated = len(keys) > PAGE_SIZE
        result = ET.Element('ListBucketResult')
        for name, value in [('Name', 'local-fake-oss'), ('Prefix', quote(prefix, safe='')), ('EncodingType', 'url'), ('MaxKeys', str(PAGE_SIZE)), ('KeyCount', str(len(selected))), ('IsTruncated', 'true' if truncated else 'false')]:
            ET.SubElement(result, name).text = value
        for key, size in selected:
            node = ET.SubElement(result, 'Contents')
            ET.SubElement(node, 'Key').text = quote(key, safe='')
            ET.SubElement(node, 'Size').text = str(size)
            ET.SubElement(node, 'LastModified').text = '2026-10-28T00:00:00.000Z'
        if truncated:
            ET.SubElement(result, 'NextContinuationToken').text = base64.b64encode(selected[-1][0].encode()).decode()
        self.reply(200, ET.tostring(result, encoding='utf-8'), 'application/xml')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--state', required=True, type=Path)
    parser.add_argument('--pool', required=True)
    args = parser.parse_args()
    if not re.fullmatch(r'[a-fA-F0-9]{64}', args.pool):
        parser.error('--pool must be the exact 64-hex client pool identifier')
    os.umask(0o077)
    stop = threading.Event()
    signal.signal(signal.SIGTERM, lambda *_: stop.set())
    signal.signal(signal.SIGINT, lambda *_: stop.set())
    with tempfile.TemporaryDirectory(prefix='async-http-fixture-v134-') as directory:
        oss = BoundedServer(('127.0.0.1', 0), FakeOSSHandler)
        oss.objects, oss.object_lock = {}, threading.Lock()
        signer = FixtureSigner(f'http://127.0.0.1:{oss.server_address[1]}')
        service = Service(Path(directory) / 'state.db', Settings(pool_ids=(args.pool,)), signer)
        api = make_server(service, ('127.0.0.1', 0))
        threads = [threading.Thread(target=lambda server=server: server.serve_forever(poll_interval=.05), daemon=True) for server in (oss, api)]
        for thread in threads:
            thread.start()
        try:
            state = {'base_url': f'http://127.0.0.1:{api.server_address[1]}', 'invite_a': service.create_invite(), 'invite_b': service.create_invite()}
            # Readiness is atomic; the caller owns the explicit state path.
            temporary_state = args.state.with_name(args.state.name + '.tmp')
            temporary_state.write_text(json.dumps(state), encoding='utf-8')
            temporary_state.chmod(0o600)
            temporary_state.replace(args.state)
            print('fixture_ready', flush=True)
            stop.wait()
        finally:
            # Drain authorization first: accepted requests may still issue fake URLs.
            api.shutdown(); api.server_close()
            oss.shutdown(); oss.server_close()
            for thread in threads:
                thread.join()
            service.close()
            args.state.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
