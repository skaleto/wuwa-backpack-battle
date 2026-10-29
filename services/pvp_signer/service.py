"""Authorization only: never receives game snapshots or runs a battle."""
from dataclasses import dataclass
import hashlib
import hmac
import json
from pathlib import Path
import re
import secrets
import sqlite3
import threading
import time

MAX_BYTES = 262144
SAFE_ID = re.compile(r'[A-Za-z0-9_-]{1,128}')
RUN_ID = re.compile(r'[A-Za-z0-9_-]{1,64}')
SHA256 = re.compile(r'[a-fA-F0-9]{64}')


class ApiError(Exception):
    def __init__(self, status, code):
        self.status, self.code = status, code
        super().__init__(code)


@dataclass
class Settings:
    pool_ids: tuple = ()
    identity_hour_limit: int = 600
    ip_hour_limit: int = 1800
    session_hour_limit: int = 30
    token_ttl: int = 30 * 86400
    device_token_ttl: int = 86400
    device_hour_limit: int = 30

    def __post_init__(self):
        if any(not isinstance(p, str) or not SAFE_ID.fullmatch(p) for p in self.pool_ids):
            raise ValueError('Invalid pool allowlist')
        if any(type(v) is not int or v <= 0 for v in (self.identity_hour_limit, self.ip_hour_limit, self.session_hour_limit, self.token_ttl, self.device_token_ttl, self.device_hour_limit)):
            raise ValueError('Limits must be positive integers')


def digest(value):
    return hashlib.sha256(value.encode()).hexdigest()


def require(condition, code='invalid_request', status=400):
    if not condition:
        raise ApiError(status, code)


def fields(body, required, optional=()):
    require(isinstance(body, dict))
    require(set(required) <= body.keys() and body.keys() <= set(required) | set(optional))


def integer(value, low, high):
    return type(value) is int and low <= value <= high


class Service:
    def __init__(self, database, settings, signer=None, clock=time.time):
        self.settings, self.signer, self.clock = settings, signer, clock
        self.lock = threading.RLock()
        self.db = sqlite3.connect(str(database), check_same_thread=False, timeout=10)
        self.db.row_factory = sqlite3.Row
        self.db.executescript('''
            PRAGMA journal_mode=WAL;
            PRAGMA foreign_keys=ON;
            CREATE TABLE IF NOT EXISTS players (
                id TEXT PRIMARY KEY, token_hash TEXT UNIQUE NOT NULL,
                expires INTEGER NOT NULL, revoked INTEGER NOT NULL DEFAULT 0);
            CREATE TABLE IF NOT EXISTS invites (
                hash TEXT PRIMARY KEY, expires INTEGER NOT NULL,
                request_hash TEXT, player_id TEXT REFERENCES players(id),
                revoked INTEGER NOT NULL DEFAULT 0);
            CREATE TABLE IF NOT EXISTS uploads (
                player_id TEXT NOT NULL REFERENCES players(id), run_id TEXT NOT NULL,
                round INTEGER NOT NULL, metadata TEXT NOT NULL, object_key TEXT NOT NULL,
                PRIMARY KEY(player_id, run_id, round));
            CREATE TABLE IF NOT EXISTS quota (
                subject TEXT NOT NULL, window INTEGER NOT NULL, count INTEGER NOT NULL,
                PRIMARY KEY(subject, window));
            CREATE TABLE IF NOT EXISTS devices (
                installation_id TEXT PRIMARY KEY, secret_hash TEXT NOT NULL,
                player_id TEXT UNIQUE NOT NULL REFERENCES players(id),
                legacy_token_hash TEXT, legacy_expires INTEGER);
        ''')
        self.db.commit()
    def close(self):
        self.db.close()
    def create_invite(self, ttl=7 * 86400):
        require(integer(ttl, 1, 365 * 86400))
        invite = secrets.token_urlsafe(32)
        with self.lock, self.db:
            self.db.execute('INSERT INTO invites(hash,expires) VALUES (?,?)', (digest(invite), int(self.clock()) + ttl))
        return invite
    def list_invites(self):
        with self.lock:
            return [dict(row) for row in self.db.execute('SELECT hash,expires,player_id,revoked FROM invites ORDER BY expires DESC')]
    def revoke(self, player_id):
        with self.lock, self.db:
            self.db.execute('UPDATE players SET revoked=1 WHERE id=?', (player_id,))
    def revoke_invite(self, invite_hash):
        with self.lock, self.db:
            self.db.execute('UPDATE invites SET revoked=1 WHERE hash=?', (invite_hash,))
    def _quota(self, subject, limit):
        window = int(self.clock()) // 3600
        # Commit attempts independently: rejecting auth must not roll back its IP quota.
        with self.db:
            self.db.execute('DELETE FROM quota WHERE window < ?', (window - 1,))
            row = self.db.execute('SELECT count FROM quota WHERE subject=? AND window=?', (subject, window)).fetchone()
            require(row is None or row['count'] < limit, 'quota_exceeded', 429)
            self.db.execute('INSERT INTO quota VALUES (?,?,1) ON CONFLICT(subject,window) DO UPDATE SET count=count+1', (subject, window))
    def charge_session_attempt(self, ip):
        # HTTP calls this before parsing; direct dispatch calls it by default.
        with self.lock:
            self._quota('session-ip:' + digest(ip), self.settings.session_hour_limit)
    def _session(self, body):
        fields(body, ('invite',), ('request_id',))
        invite = body['invite']
        require(isinstance(invite, str) and 1 <= len(invite) <= 128)
        request_id = body.get('request_id', secrets.token_urlsafe(32))
        require(isinstance(request_id, str) and re.fullmatch(r'[A-Za-z0-9_-]{32,128}', request_id))
        now = int(self.clock())
        with self.db:
            # Also serialize separate CLI/service processes sharing this database.
            self.db.execute('BEGIN IMMEDIATE')
            row = self.db.execute('SELECT * FROM invites WHERE hash=?', (digest(invite),)).fetchone()
            require(row is not None and not row['revoked'], 'invalid_invite', 401)
            if row['player_id']:
                require(hmac.compare_digest(row['request_hash'], digest(request_id)), 'invite_consumed', 409)
                player_id = row['player_id']
                player = self.db.execute('SELECT * FROM players WHERE id=?', (player_id,)).fetchone()
                require(not player['revoked'] and player['expires'] > now, 'session_expired', 401)
                require(self.db.execute('SELECT 1 FROM devices WHERE player_id=?', (player_id,)).fetchone() is None, 'device_already_bound', 409)
            else:
                require(row['expires'] > now, 'invalid_invite', 401)
                player_id = secrets.token_hex(16)
            # The high entropy invite is the recovery secret; no recoverable credential is stored.
            token = hmac.new(invite.encode(), ('pvp-session-v1\0' + request_id + '\0' + player_id).encode(), hashlib.sha256).hexdigest()
            if not row['player_id']:
                self.db.execute('INSERT INTO players(id,token_hash,expires) VALUES (?,?,?)', (player_id, digest(token), now + self.settings.token_ttl))
                self.db.execute('UPDATE invites SET request_hash=?,player_id=? WHERE hash=?', (digest(request_id), player_id, digest(invite)))
        return {'player_id': player_id, 'token': token}
    def _device_session(self, body, authorization):
        fields(body, ('installation_id', 'secret'))
        installation, secret = body['installation_id'], body['secret']
        require(isinstance(installation, str) and re.fullmatch(r'[a-f0-9]{32}', installation))
        # Count valid device IDs even when their supplied secret is malformed or wrong.
        self._quota('device:' + installation, self.settings.device_hour_limit)
        require(isinstance(secret, str) and re.fullmatch(r'[a-f0-9]{64}', secret))
        now = int(self.clock())
        with self.db:
            self.db.execute('BEGIN IMMEDIATE')
            device = self.db.execute('SELECT * FROM devices WHERE installation_id=?', (installation,)).fetchone()
            legacy_hash, legacy_expires = None, None
            if device:
                require(hmac.compare_digest(device['secret_hash'], digest(secret)), 'unauthorized', 401)
                player = self.db.execute('SELECT * FROM players WHERE id=?', (device['player_id'],)).fetchone()
                require(player is not None and not player['revoked'], 'unauthorized', 401)
                if authorization:
                    # A lost binding response may be retried with its original valid bearer.
                    # This hash authorizes only this already-bound device, never a second one.
                    valid_legacy = (isinstance(authorization, str) and authorization.startswith('Bearer ')
                                    and len(authorization) <= 256 and device['legacy_token_hash']
                                    and device['legacy_expires'] > now
                                    and hmac.compare_digest(device['legacy_token_hash'], digest(authorization[7:])))
                    if not valid_legacy:
                        require(self._authenticate(authorization) == player['id'], 'unauthorized', 401)
                player_id, expires = player['id'], player['expires']
            elif authorization:
                player_id = self._authenticate(authorization)
                require(self.db.execute('SELECT 1 FROM devices WHERE player_id=?', (player_id,)).fetchone() is None, 'device_already_bound', 409)
                player = self.db.execute('SELECT * FROM players WHERE id=?', (player_id,)).fetchone()
                legacy_hash, legacy_expires = player['token_hash'], player['expires']
                expires = now + self.settings.device_token_ttl
            else:
                player_id, expires = secrets.token_hex(16), now + self.settings.device_token_ttl
            if expires <= now:
                expires = now + self.settings.device_token_ttl
            # The client-held random secret permits deterministic response-loss recovery;
            # neither it nor any bearer is stored in recoverable form on the server.
            token = hmac.new(secret.encode(), f'pvp-device-v1\0{installation}\0{player_id}\0{expires}'.encode(), hashlib.sha256).hexdigest()
            if device or legacy_hash:
                self.db.execute('UPDATE players SET token_hash=?,expires=? WHERE id=?', (digest(token), expires, player_id))
            else:
                self.db.execute('INSERT INTO players(id,token_hash,expires) VALUES (?,?,?)', (player_id, digest(token), expires))
            if not device:
                self.db.execute('INSERT INTO devices VALUES (?,?,?,?,?)', (installation, digest(secret), player_id, legacy_hash, legacy_expires))
        return {'player_id': player_id, 'token': token, 'expires_at': expires}
    def _authenticate(self, authorization):
        require(isinstance(authorization, str) and authorization.startswith('Bearer ') and len(authorization) <= 256, 'unauthorized', 401)
        row = self.db.execute('SELECT * FROM players WHERE token_hash=?', (digest(authorization[7:]),)).fetchone()
        require(row is not None and not row['revoked'] and row['expires'] > int(self.clock()), 'unauthorized', 401)
        return row['id']
    def _prefix(self, body):
        require(isinstance(body['pool_id'], str) and body['pool_id'] in self.settings.pool_ids, 'unknown_pool')
        require(integer(body['round'], 1, 32), 'invalid_round')
        return f"test/pools/{body['pool_id']}/round/{body['round']:02d}/"
    def _upload(self, body, player_id):
        fields(body, ('pool_id', 'round', 'wins', 'losses', 'run_id', 'sha256', 'size'))
        prefix = self._prefix(body)
        require(integer(body['wins'], 0, 31) and integer(body['losses'], 0, 31) and body['wins'] + body['losses'] == body['round'] - 1, 'invalid_record')
        require(isinstance(body['run_id'], str) and RUN_ID.fullmatch(body['run_id']), 'invalid_run_id')
        require(isinstance(body['sha256'], str) and SHA256.fullmatch(body['sha256']), 'invalid_sha256')
        require(integer(body['size'], 1, MAX_BYTES), 'invalid_size')
        body = body | {'sha256': body['sha256'].lower()}
        key = f"{prefix}wins/{body['wins']:02d}/{player_id}/{body['run_id']}-{body['sha256']}.json"
        metadata = json.dumps(body, sort_keys=True, separators=(',', ':'))
        with self.db:
            self.db.execute('BEGIN IMMEDIATE')
            row = self.db.execute('SELECT metadata,object_key FROM uploads WHERE player_id=? AND run_id=? AND round=?', (player_id, body['run_id'], body['round'])).fetchone()
            require(row is None or (row['metadata'] == metadata and row['object_key'] == key), 'upload_conflict', 409)
            if row is None:
                self.db.execute('INSERT INTO uploads VALUES (?,?,?,?,?)', (player_id, body['run_id'], body['round'], metadata, key))
        return self.signer.upload(key, body['size'], int(self.clock()))
    def _read(self, body):
        fields(body, ('pool_id', 'round'), ('key', 'continuation', 'start_after', 'wins'))
        prefix = self._prefix(body)
        if 'wins' in body:
            require('key' not in body and integer(body['wins'], 0, body['round'] - 1), 'invalid_wins')
            prefix += f"wins/{body['wins']:02d}/"
        require(not ('continuation' in body and 'start_after' in body))
        if 'key' in body:
            require(not ('continuation' in body or 'start_after' in body))
            key = body['key']
            require(isinstance(key, str))
            match = re.fullmatch(re.escape(prefix) + r'wins/(\d{2})/[a-f0-9]{32}/[A-Za-z0-9_-]{1,64}-[a-f0-9]{64}\.json', key)
            require(match is not None and int(match[1]) < body['round'], 'invalid_key')
            return self.signer.read(key, {}, int(self.clock()))
        params = {'list-type': '2', 'prefix': prefix, 'max-keys': '100', 'encoding-type': 'url'}
        for field, query in (('continuation', 'continuation-token'), ('start_after', 'start-after')):
            if field in body:
                value = body[field]
                require(isinstance(value, str) and 1 <= len(value) <= 2048 and all(32 <= ord(c) < 127 for c in value))
                if field == 'start_after':
                    require(value.startswith(prefix) and '..' not in value and '%' not in value)
                params[query] = value
        return self.signer.read('', params, int(self.clock()))
    def dispatch(self, method, path, body=None, authorization='', ip='unknown', *, session_quota_charged=False):
        with self.lock:
            if method == 'GET' and path == '/config':
                return {'protocol': 1, 'pool_ids': list(self.settings.pool_ids), 'max_bytes': MAX_BYTES}
            if method == 'GET' and path == '/healthz':
                return {'status': 'configured' if self.signer else 'unconfigured', 'protocol': 1}
            if method == 'POST' and path == '/sessions':
                if not session_quota_charged:
                    self.charge_session_attempt(ip)
                return self._session(body)
            if method == 'POST' and path == '/devices/session':
                if not session_quota_charged:
                    self.charge_session_attempt(ip)
                return self._device_session(body, authorization)
            if method == 'POST' and path in ('/storage/upload-ticket', '/storage/read-ticket'):
                self._quota('ticket-ip:' + digest(ip), self.settings.ip_hour_limit)
                player_id = self._authenticate(authorization)
                self._quota('player:' + player_id, self.settings.identity_hour_limit)
                require(self.signer is not None, 'storage_unconfigured', 503)
                return self._upload(body, player_id) if path.endswith('upload-ticket') else self._read(body)
            raise ApiError(404, 'not_found')
