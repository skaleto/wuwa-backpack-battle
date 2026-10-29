"""Explicit, server-only OSS smoke. Never print credentials, tickets or payloads.

Run with /opt/pvp-signer/.venv/bin/python .../real_oss_smoke.py on the authorized ECS.
Only uses the configured dedicated bucket and a run-specific round-32 test prefix.
Creates small immutable QA objects; does not delete or change any bucket policy.
"""
from datetime import datetime, timedelta, timezone
import hashlib
import json
import os
from pathlib import Path
import secrets
import sys
import time
from unittest.mock import patch
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
import requests
from oss_signer import signer_from_env
from service import Service, Settings


def env_file():
    result = {}
    for line in Path('/etc/pvp-signer/pvp-signer.env').read_text().splitlines():
        if line and not line.startswith('#'):
            name, value = line.split('=', 1)
            result[name] = json.loads(value)
    return result


def oss_code(response):
    try:
        return ET.fromstring(response.content).findtext('Code') or ''
    except ET.ParseError:
        return ''


def main():
    os.umask(0o077)
    env = env_file()
    assert env['PVP_OSS_BUCKET'] == 'wuwa-backpack-battle'
    pool = env['PVP_POOL_IDS']
    assert ',' not in pool
    signer = signer_from_env(env)
    state = Service(env['PVP_DATABASE'], Settings())
    invite = state.create_invite(3600)
    http = requests.Session()
    api_base = 'https://skbaby.top/resonance-pvp/v1'
    report = {'bucket': env['PVP_OSS_BUCKET'], 'pool_id': pool, 'created_at': int(time.time()), 'checks': []}
    player_id = None
    def record(name, response, allowed):
        status = response.status_code
        check = {'name': name, 'status': status, 'oss_code': oss_code(response)}
        report['checks'].append(check)
        print(json.dumps(check), flush=True)
        if status not in allowed:
            raise AssertionError('Unexpected status for ' + name)
    def api(path, body, token=''):
        headers = {'Authorization': 'Bearer ' + token} if token else {}
        response = http.post(api_base + path, json=body, headers=headers, timeout=15)
        if response.status_code != 200:
            raise AssertionError('API failed: ' + path + ' status=' + str(response.status_code))
        return response.json()
    def post(ticket, payload, changes=None):
        fields = ticket['fields'] | (changes or {})
        return http.post(ticket['url'], data=fields, files={'file': ('ghost.json', payload, 'application/json')}, timeout=20)
    def change_query(url, changes):
        parsed = urlsplit(url)
        params = dict(parse_qsl(parsed.query)); params.update(changes)
        return urlunsplit((parsed.scheme, parsed.netloc, parsed.path, urlencode(params), ''))
    try:
        session = api('/sessions', {'invite': invite, 'request_id': secrets.token_hex(32)})
        player_id, token = session['player_id'], session['token']
        round_number = 32
        run_prefix = 'deployqa_' + secrets.token_hex(6)
        tickets = []
        payloads = []
        for index in range(3):
            # Test-only tiny envelope. Client should reject it as an incomplete ghost.
            payload = json.dumps({'schema': 1, 'deployment_smoke': True, 'index': index}, separators=(',', ':')).encode()
            body = {'pool_id': pool, 'round': round_number, 'wins': 0, 'losses': 31, 'run_id': run_prefix + '_' + str(index), 'sha256': hashlib.sha256(payload).hexdigest(), 'size': len(payload)}
            ticket = api('/storage/upload-ticket', body, token)
            record('upload_' + str(index), post(ticket, payload), {200, 201, 204})
            retry = api('/storage/upload-ticket', body, token)
            assert retry['key'] == ticket['key']
            tickets.append(ticket); payloads.append(payload)
        ticket, payload = tickets[0], payloads[0]
        record('same_key_forbid_overwrite', post(ticket, payload), {409})
        # Check conditions against a not-yet-created key: OSS reports overwrite
        # conflicts before evaluating content-length for an existing object.
        guard = api('/storage/upload-ticket', {'pool_id': pool, 'round': 32, 'wins': 0, 'losses': 31, 'run_id': run_prefix + '_guard', 'sha256': hashlib.sha256(payload).hexdigest(), 'size': len(payload)}, token)
        record('changed_key_rejected', post(guard, payload, {'key': guard['key'] + '.altered'}), {403})
        record('changed_size_rejected', post(guard, payload + b' '), {400, 403})
        record('changed_smaller_size_rejected', post(guard, payload[:-1]), {400, 403})
        record('changed_acl_rejected', post(guard, payload, {'x-oss-object-acl': 'public-read'}), {403})
        record('changed_forbid_overwrite_rejected', post(guard, payload, {'x-oss-forbid-overwrite': 'false'}), {403})
        record('changed_effective_content_type_rejected', post(guard, payload, {'Content-Type': 'text/plain', 'x-oss-content-type': 'text/plain'}), {403})
        # OSS evaluates the effective MIME type: x-oss-content-type overrides
        # Content-Type. Altering only the lower-priority field cannot change it.
        record('overridden_content_type_keeps_json', post(guard, payload, {'Content-Type': 'text/plain'}), {200, 201, 204})
        assert signer.bucket.head_object(guard['key']).content_type == 'application/json'
        tickets.append(guard); payloads.append(payload)
        expired = signer.upload(guard['key'], len(payload), int(time.time()) - 601)
        record('expired_post_rejected', post(expired, payload), {403})
        for index, upload in enumerate(tickets):
            read = api('/storage/read-ticket', {'pool_id': pool, 'round': 32, 'key': upload['key']}, token)
            response = http.get(read['url'], timeout=15)
            record('download_' + str(index), response, {200})
            assert response.content == payloads[index]
            acl = signer.bucket.get_object_acl(upload['key']).acl
            assert acl == 'private'
        print(json.dumps({'name': 'exact_bytes_and_private_acl', 'passed': True}), flush=True)
        read = api('/storage/read-ticket', {'pool_id': pool, 'round': 32, 'key': ticket['key']}, token)
        parsed = urlsplit(read['url'])
        unsigned = urlunsplit((parsed.scheme, parsed.netloc, parsed.path, '', ''))
        record('anonymous_get_rejected', http.get(unsigned, timeout=15), {403})
        record('get_ticket_cannot_delete', http.delete(read['url'], timeout=15), {403})
        record('get_ticket_cannot_change_acl', http.put(change_query(read['url'], {'acl': ''}), headers={'x-oss-object-acl': 'public-read'}, timeout=15), {403})
        prefix = f'test/pools/{pool}/round/32/'
        listed = api('/storage/read-ticket', {'pool_id': pool, 'round': 32}, token)
        response = http.get(listed['url'], timeout=15)
        record('api_list', response, {200})
        root = ET.fromstring(response.content)
        assert len(root.findall('Contents')) >= 3
        record('tampered_list_prefix_rejected', http.get(change_query(listed['url'], {'prefix': prefix.replace('/32/', '/31/')}), timeout=15), {403})
        record('tampered_max_keys_rejected', http.get(change_query(listed['url'], {'max-keys': '1'}), timeout=15), {403})
        # Service fixes max-keys=100. Use the same SDK adapter with max-keys=1
        # to obtain a real continuation token without creating >100 test objects.
        params = {'list-type': '2', 'prefix': prefix, 'max-keys': '1', 'encoding-type': 'url'}
        first = signer.read('', params, int(time.time()))
        response = http.get(first['url'], timeout=15)
        record('real_pagination_first', response, {200})
        root = ET.fromstring(response.content)
        assert root.findtext('IsTruncated') == 'true' and len(root.findall('Contents')) == 1
        continuation = root.findtext('NextContinuationToken')
        next_ticket = api('/storage/read-ticket', {'pool_id': pool, 'round': 32, 'continuation': continuation}, token)
        response = http.get(next_ticket['url'], timeout=15)
        record('api_real_continuation', response, {200})
        assert len(ET.fromstring(response.content).findall('Contents')) >= 2
        start_ticket = api('/storage/read-ticket', {'pool_id': pool, 'round': 32, 'start_after': tickets[0]['key']}, token)
        record('api_start_after', http.get(start_ticket['url'], timeout=15), {200})
        with patch('oss2.auth.datetime') as frozen:
            frozen.utcnow.return_value = datetime.now(timezone.utc).replace(tzinfo=None) - timedelta(seconds=601)
            expired_get = signer.read(ticket['key'], {}, int(time.time()) - 601)
        record('expired_get_rejected', http.get(expired_get['url'], timeout=15), {403})
        report['object_keys'] = [item['key'] for item in tickets]
        report['passed'] = True
    except Exception as error:
        # Exception messages may contain signed URLs. Only expose the class.
        report['passed'] = False
        report['failure_type'] = type(error).__name__
        print(json.dumps({'smoke_failed': type(error).__name__}), flush=True)
    finally:
        if player_id:
            state.revoke(player_id)
        state.close()
        Path('/var/lib/pvp-signer/real-oss-smoke-report.json').write_text(json.dumps(report, indent=2))
        http.close()
    return 0 if report.get('passed') else 1


if __name__ == '__main__':
    raise SystemExit(main())
