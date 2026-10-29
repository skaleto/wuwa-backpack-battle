"""Offline OSS V4 signing. No SDK network operations occur here."""
import base64
from datetime import datetime, timezone
import hashlib
import hmac
import json
import re

TTL = 300


class OssSigner:
    configured = True
    def __init__(self, bucket, region, access_id, secret):
        if not re.fullmatch(r'[a-z0-9][a-z0-9-]{1,61}[a-z0-9]', bucket) or not re.fullmatch(r'[a-z]+-[a-z0-9-]+', region):
            raise ValueError('Invalid OSS bucket or region')
        import oss2
        self.bucket_name, self.region = bucket, region
        self.access_id, self.secret = access_id, secret
        self.url = f'https://{bucket}.oss-{region}.aliyuncs.com/'
        self.auth = oss2.AuthV4(access_id, secret)
        self.bucket = oss2.Bucket(self.auth, f'https://oss-{region}.aliyuncs.com', bucket, region=region)
    def upload(self, key, size, now):
        stamp = datetime.fromtimestamp(now, timezone.utc).strftime('%Y%m%dT%H%M%SZ')
        scope = f'{stamp[:8]}/{self.region}/oss/aliyun_v4_request'
        fields = {
            'key': key,
            'x-oss-signature-version': 'OSS4-HMAC-SHA256',
            'x-oss-credential': self.access_id + '/' + scope,
            'x-oss-date': stamp,
            'x-oss-object-acl': 'private',
            'Content-Type': 'application/json',
            # This OSS field takes precedence over the file part's MIME type.
            'x-oss-content-type': 'application/json',
            'x-oss-forbid-overwrite': 'true',
            'success_action_status': '201',
        }
        conditions = [{'bucket': self.bucket_name}] + [{k: v} for k, v in fields.items()]
        conditions.append(['content-length-range', size, size])
        policy = {'expiration': datetime.fromtimestamp(now + TTL, timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.000Z'), 'conditions': conditions}
        encoded = base64.b64encode(json.dumps(policy, separators=(',', ':')).encode()).decode()
        # oss2 has no POST-policy signing API. This is the official documented V4 derivation.
        signing_key = ('aliyun_v4' + self.secret).encode()
        for segment in scope.split('/'):
            signing_key = hmac.new(signing_key, segment.encode(), hashlib.sha256).digest()
        fields['policy'] = encoded
        fields['x-oss-signature'] = hmac.new(signing_key, encoded.encode(), hashlib.sha256).hexdigest()
        return {'key': key, 'url': self.url, 'fields': fields, 'expires_at': now + TTL}
    def read(self, key, params, now):
        if key:
            url = self.bucket.sign_url('GET', key, TTL, params=dict(params), slash_safe=True)
        else:
            # oss2 2.19.1 Bucket.sign_url rejects empty keys. Its AuthV4 signs the
            # bucket-level Request correctly, including every query parameter.
            from oss2.http import Request
            request = Request('GET', self.url, params=dict(params), region=self.region, product='oss')
            url = self.auth._sign_url(request, self.bucket_name, '', TTL)
        return {'url': url, 'expires_at': now + TTL}


def signer_from_env(env):
    names = ('PVP_OSS_BUCKET', 'PVP_OSS_REGION', 'PVP_OSS_ACCESS_KEY_ID', 'PVP_OSS_ACCESS_KEY_SECRET')
    if env.get('PVP_OSS_VERSIONING') != 'never-enabled' or not all(env.get(name) for name in names):
        return None
    return OssSigner(*(env[name] for name in names))
